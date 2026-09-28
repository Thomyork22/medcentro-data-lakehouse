/* ============================================================================
   CLÍNICA MEDCENTRO S.A. — DATA LAKEHOUSE CON ARQUITECTURA MEDALLÓN
   Script de resumen: estructura completa Bronze / Silver / Gold
   Actividad 1 y 2 — Arquitectura y Almacenamiento de Datos (INACAP)
   Integrantes: Thomas Cortés, Nicolás Gacitúa, Miguel Pineda
   ----------------------------------------------------------------------------
   Este script documenta el DDL completo de las tres zonas del Lakehouse,
   tal como fueron implementadas mediante Pentaho Data Integration 10.2.
   No reemplaza la ejecución real vía Pentaho (que es la usada en producción
   del proyecto): es un resumen consolidado en SQL para fines de evidencia
   y evaluación.

   Motor: SQL Server 2019 Express — instancia localhost\SQL
   Base de datos: MedCentro_Lakehouse
   ============================================================================ */

USE MedCentro_Lakehouse;
GO

IF SCHEMA_ID('Bronze') IS NULL EXEC('CREATE SCHEMA Bronze');
IF SCHEMA_ID('Silver') IS NULL EXEC('CREATE SCHEMA Silver');
IF SCHEMA_ID('Gold')   IS NULL EXEC('CREATE SCHEMA Gold');
GO

/* ============================================================================
   TABLA DE TRAZABILIDAD — VALIDACIÓN DE FUENTES (Criterio 1, Actividad 1)
   ============================================================================
   Poblada por 01_validacion_fuentes.ktr: UNION ALL sobre las 11 tablas
   origen, contando registros totales y nulos en 2 campos clave por tabla.
   ============================================================================ */
CREATE TABLE dbo.LogValidacionFuentes (
    TablaOrigen         VARCHAR(60)     NOT NULL,
    TotalRegistros      INT             NOT NULL,
    NulosCampo1         INT             NOT NULL,
    NulosCampo2         INT             NOT NULL,
    FechaValidacion     DATETIME2       NOT NULL DEFAULT SYSDATETIME()
);
GO


/* ============================================================================
   ============================================================================
   ZONA BRONZE — CAPA CRUDA (Criterio 2, Actividad 1)
   ============================================================================
   ============================================================================
   Diseño intencional: SIN Primary Key ni Foreign Key (schema-on-write).
   Cada tabla replica exactamente la estructura de su tabla origen, sumando
   2 columnas de auditoría:
     - FechaCargaBronze  DATETIME2      (step "Get System Info" en Pentaho)
     - UsuarioCargaBronze NVARCHAR(50)  (step "Add constants", valor fijo
                                          'ETL_Pentaho_MedCentro')
   Carga: Table Input -> Get System Info -> Add constants -> Table Output,
   con "Truncate table" activado (idempotente).
   ============================================================================ */

-- ---------- Esquema HIS (02_bronze_HIS.ktr) ----------
CREATE TABLE Bronze.HIS_Paciente (
    PacienteHISID       VARCHAR(20)     NULL,
    RUN                  VARCHAR(12)     NULL,
    Nombres              NVARCHAR(80)    NULL,
    Apellidos            NVARCHAR(80)    NULL,
    Sexo                 CHAR(1)         NULL,
    FechaNacimiento      DATE            NULL,
    Comuna               NVARCHAR(80)    NULL,
    Region               NVARCHAR(80)    NULL,
    Prevision            NVARCHAR(30)    NULL,
    Telefono             VARCHAR(20)     NULL,
    Email                NVARCHAR(120)   NULL,
    FechaRegistro        DATETIME2(0)    NULL,
    Activo               BIT             NULL,
    FechaCargaBronze     DATETIME2       NULL,
    UsuarioCargaBronze   NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.HIS_Profesional (
    ProfesionalHISID     VARCHAR(20)     NULL,
    RUN                   VARCHAR(12)     NULL,
    NombreCompleto        NVARCHAR(120)   NULL,
    Especialidad          NVARCHAR(80)    NULL,
    RegistroSIS           VARCHAR(30)     NULL,
    SedeBase              NVARCHAR(60)    NULL,
    FechaCargaBronze      DATETIME2       NULL,
    UsuarioCargaBronze    NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.HIS_EpisodioClinico (
    EpisodioHISID        VARCHAR(20)     NULL,
    PacienteHISID        VARCHAR(20)     NULL,
    FechaHoraIngreso     DATETIME2(0)    NULL,
    FechaHoraAlta        DATETIME2(0)    NULL,
    Sede                 NVARCHAR(60)    NULL,
    Servicio             NVARCHAR(80)    NULL,
    TipoAtencion         NVARCHAR(40)    NULL,
    Cama                 NVARCHAR(20)    NULL,
    ProfesionalHISID     VARCHAR(20)     NULL,
    MotivoConsulta       NVARCHAR(250)   NULL,
    EstadoEpisodio       NVARCHAR(30)    NULL,
    SistemaOrigen        VARCHAR(20)     NULL,
    FechaCargaBronze     DATETIME2       NULL,
    UsuarioCargaBronze   NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.HIS_DiagnosticoEpisodio (
    DiagnosticoHISID     INT             NULL,
    EpisodioHISID        VARCHAR(20)     NULL,
    CodigoCIE10          VARCHAR(10)     NULL,
    DescripcionCIE10     NVARCHAR(200)   NULL,
    TipoDiagnostico      NVARCHAR(30)    NULL,
    FechaDiagnostico     DATETIME2(0)    NULL,
    FechaCargaBronze     DATETIME2       NULL,
    UsuarioCargaBronze   NVARCHAR(50)    NULL
);
GO

-- ---------- Esquema LIS (03_bronze_LIS.ktr) ----------
CREATE TABLE Bronze.LIS_OrdenLaboratorio (
    OrdenLISID           VARCHAR(20)     NULL,
    PacienteHISID        VARCHAR(20)     NULL,
    EpisodioHISID        VARCHAR(20)     NULL,
    CodigoOrden          VARCHAR(30)     NULL,
    FechaSolicitud       DATETIME2(0)    NULL,
    FechaResultado       DATETIME2(0)    NULL,
    TipoMuestra          NVARCHAR(60)    NULL,
    EstadoOrden          NVARCHAR(30)    NULL,
    SistemaOrigen        VARCHAR(20)     NULL,
    FechaCargaBronze     DATETIME2       NULL,
    UsuarioCargaBronze   NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.LIS_ResultadoLaboratorio (
    ResultadoLISID       INT             NULL,
    OrdenLISID           VARCHAR(20)     NULL,
    CodigoLOINC          VARCHAR(20)     NULL,
    NombreExamen         NVARCHAR(120)   NULL,
    ResultadoValor       DECIMAL(12,3)   NULL,
    ResultadoTexto       NVARCHAR(120)   NULL,
    UnidadMedida         NVARCHAR(30)    NULL,
    RangoReferencia      NVARCHAR(60)    NULL,
    FlagResultado        NVARCHAR(20)    NULL,
    HL7Mensaje           NVARCHAR(MAX)   NULL,
    FechaRegistro        DATETIME2(0)    NULL,
    FechaCargaBronze     DATETIME2       NULL,
    UsuarioCargaBronze   NVARCHAR(50)    NULL
);
GO

-- ---------- Esquema PACS (04_bronze_PACS.ktr) ----------
CREATE TABLE Bronze.PACS_EstudioDICOM (
    EstudioPACSID         VARCHAR(20)     NULL,
    PacienteHISID         VARCHAR(20)     NULL,
    EpisodioHISID         VARCHAR(20)     NULL,
    AccessionNumber       VARCHAR(40)     NULL,
    StudyInstanceUID      VARCHAR(100)    NULL,
    Modalidad             VARCHAR(10)     NULL,
    RegionAnatomica       NVARCHAR(80)    NULL,
    FechaEstudio          DATETIME2(0)    NULL,
    InformeRadiologico    NVARCHAR(500)   NULL,
    EstadoInforme         NVARCHAR(30)    NULL,
    TamanoMB              DECIMAL(10,2)   NULL,
    UriObjectStorage      NVARCHAR(300)   NULL,
    DicomMetadataJson     NVARCHAR(MAX)   NULL,
    SistemaOrigen         VARCHAR(20)     NULL,
    FechaCargaBronze      DATETIME2       NULL,
    UsuarioCargaBronze    NVARCHAR(50)    NULL
);
GO

-- ---------- Esquema IOT (05_bronze_IOT.ktr) ----------
CREATE TABLE Bronze.IOT_SesionMonitorizacionUCI (
    SesionIOTID           VARCHAR(20)     NULL,
    PacienteHISID         VARCHAR(20)     NULL,
    EpisodioHISID         VARCHAR(20)     NULL,
    DispositivoID         VARCHAR(40)     NULL,
    ModeloDispositivo     NVARCHAR(80)    NULL,
    Cama                  NVARCHAR(20)    NULL,
    FechaInicio           DATETIME2(0)    NULL,
    FechaFin              DATETIME2(0)    NULL,
    EstadoSesion          NVARCHAR(30)    NULL,
    SistemaOrigen         VARCHAR(20)     NULL,
    FechaCargaBronze      DATETIME2       NULL,
    UsuarioCargaBronze    NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.IOT_EventoSignosVitalesMQTT (
    EventoIOTID           BIGINT          NULL,
    SesionIOTID           VARCHAR(20)     NULL,
    TopicMQTT             NVARCHAR(150)   NULL,
    FechaEvento           DATETIME2(0)    NULL,
    PayloadJson           NVARCHAR(MAX)   NULL,  -- JSON crudo sin parsear (se parsea en Silver)
    FechaIngesta          DATETIME2(0)    NULL,
    FechaCargaBronze      DATETIME2       NULL,
    UsuarioCargaBronze    NVARCHAR(50)    NULL
);
GO

-- ---------- Esquema SAP (06_bronze_SAP.ktr) ----------
CREATE TABLE Bronze.SAP_DocumentoFinanciero (
    DocumentoSAPID        VARCHAR(20)     NULL,
    Sociedad               VARCHAR(10)     NULL,
    PacienteHISID          VARCHAR(20)     NULL,
    EpisodioHISID          VARCHAR(20)     NULL,
    CodigoClienteSAP       VARCHAR(30)     NULL,
    FechaEmision           DATE            NULL,
    FechaVencimiento       DATE            NULL,
    Prevision              NVARCHAR(30)    NULL,
    CentroCosto            NVARCHAR(80)    NULL,
    Moneda                 CHAR(3)         NULL,
    MontoBruto             DECIMAL(14,2)   NULL,
    Descuento              DECIMAL(14,2)   NULL,
    MontoNeto              DECIMAL(14,2)   NULL,
    MontoCopago             DECIMAL(14,2)   NULL,
    EstadoPago              NVARCHAR(30)    NULL,
    DocumentoJson           NVARCHAR(MAX)   NULL,
    SistemaOrigen           VARCHAR(20)     NULL,
    FechaCargaBronze        DATETIME2       NULL,
    UsuarioCargaBronze      NVARCHAR(50)    NULL
);
GO

CREATE TABLE Bronze.SAP_DetalleDocumento (
    DetalleSAPID           INT             NULL,
    DocumentoSAPID         VARCHAR(20)     NULL,
    CodigoPrestacion       VARCHAR(30)     NULL,
    Descripcion            NVARCHAR(200)   NULL,
    Cantidad               DECIMAL(10,2)   NULL,
    PrecioUnitario         DECIMAL(14,2)   NULL,
    TotalLinea             DECIMAL(14,2)   NULL,
    FechaCargaBronze       DATETIME2       NULL,
    UsuarioCargaBronze     NVARCHAR(50)    NULL
);
GO


/* ============================================================================
   ============================================================================
   ZONA SILVER — LIMPIEZA, TRANSFORMACIÓN Y ANONIMIZACIÓN (Criterio 3, Act. 1)
   ============================================================================
   ============================================================================
   Cumplimiento Ley N° 21.541 (protección de datos de salud):
     - RUN del paciente  -> hash SHA-256 irreversible (RUN_Hash), generado
       con el step nativo "Add a checksum" (Type: SHA-256) en Pentaho.
     - Nombres/Apellidos -> reducidos a Iniciales, generado con un step
       "User defined Java expression".
     - Teléfono y Email  -> eliminados, no se propagan desde Bronze.
   A diferencia de Bronze, todas las tablas Silver SÍ tienen Primary Key,
   más una columna de auditoría FechaCargaSilver.
   Las tablas de IOT y SAP incorporan además la estructuración de payloads
   JSON (parseo manual con "Modified JavaScript Value" en Pentaho, debido a
   un bug del step nativo "JSON Input" en PDI 10.2).
   ============================================================================ */

-- ---------- 07_silver_HIS.ktr ----------
CREATE TABLE Silver.HIS_Paciente (
    PacienteHISID        VARCHAR(20)     NOT NULL,
    RUN_Hash              VARCHAR(64)     NOT NULL,   -- SHA-256 hexadecimal
    Iniciales             VARCHAR(10)     NULL,
    Sexo                  CHAR(1)         NULL,
    FechaNacimiento       DATE            NULL,
    EdadAnios             INT             NULL,
    Comuna                NVARCHAR(80)    NULL,
    Region                NVARCHAR(80)    NULL,
    Prevision             NVARCHAR(30)    NULL,
    Activo                BIT             NOT NULL,
    FechaCargaSilver      DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_HIS_Paciente PRIMARY KEY CLUSTERED (PacienteHISID)
);
GO

CREATE TABLE Silver.HIS_Profesional (
    ProfesionalHISID      VARCHAR(20)     NOT NULL,
    RUN                     VARCHAR(12)     NULL,        -- personal no requiere anonimización bajo Ley 21.541
    NombreCompleto          NVARCHAR(120)   NULL,
    Especialidad            NVARCHAR(80)    NULL,
    SedeBase                NVARCHAR(60)    NULL,
    FechaCargaSilver        DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_HIS_Profesional PRIMARY KEY CLUSTERED (ProfesionalHISID)
);
GO

CREATE TABLE Silver.HIS_EpisodioClinico (
    EpisodioHISID          VARCHAR(20)     NOT NULL,
    PacienteHISID           VARCHAR(20)     NOT NULL,
    ProfesionalHISID        VARCHAR(20)     NOT NULL,
    FechaHoraIngreso        DATETIME2(0)    NULL,
    FechaHoraAlta           DATETIME2(0)    NULL,
    DuracionHoras           DECIMAL(10,2)   NULL,        -- columna calculada/enriquecida
    Sede                    NVARCHAR(60)    NULL,
    Servicio                NVARCHAR(80)    NULL,
    TipoAtencion             NVARCHAR(40)    NULL,
    EstadoEpisodio           NVARCHAR(30)    NULL,
    FechaCargaSilver         DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_HIS_EpisodioClinico PRIMARY KEY CLUSTERED (EpisodioHISID)
);
GO

CREATE TABLE Silver.HIS_DiagnosticoEpisodio (
    DiagnosticoHISID        INT             NOT NULL,
    EpisodioHISID            VARCHAR(20)     NOT NULL,
    CodigoCIE10               VARCHAR(10)     NULL,
    DescripcionCIE10           NVARCHAR(200)   NULL,
    TipoDiagnostico             NVARCHAR(30)    NULL,
    FechaDiagnostico            DATETIME2(0)    NULL,
    FechaCargaSilver             DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_HIS_DiagnosticoEpisodio PRIMARY KEY CLUSTERED (DiagnosticoHISID)
);
GO

-- ---------- 08_silver_LIS.ktr ----------
CREATE TABLE Silver.LIS_OrdenLaboratorio (
    OrdenLISID              VARCHAR(20)     NOT NULL,
    PacienteHISID            VARCHAR(20)     NULL,
    EpisodioHISID             VARCHAR(20)     NULL,
    FechaSolicitud             DATETIME2(0)    NULL,
    FechaResultado              DATETIME2(0)    NULL,
    TipoMuestra                  NVARCHAR(60)    NULL,
    EstadoOrden                   NVARCHAR(30)    NULL,
    FechaCargaSilver                DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_LIS_OrdenLaboratorio PRIMARY KEY CLUSTERED (OrdenLISID)
);
GO

CREATE TABLE Silver.LIS_ResultadoLaboratorio (
    ResultadoLISID           INT             NOT NULL,
    OrdenLISID                 VARCHAR(20)     NOT NULL,
    CodigoLOINC                  VARCHAR(20)     NULL,
    NombreExamen                   NVARCHAR(120)   NULL,
    ResultadoValor                   DECIMAL(12,3)   NULL,
    UnidadMedida                       NVARCHAR(30)    NULL,
    RangoReferencia                      NVARCHAR(60)    NULL,
    FlagResultado                          NVARCHAR(20)    NULL,   -- 'Normal' / 'Alterado', calculado
    FechaCargaSilver                         DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_LIS_ResultadoLaboratorio PRIMARY KEY CLUSTERED (ResultadoLISID),
    CONSTRAINT FK_Silver_Resultado_Orden FOREIGN KEY (OrdenLISID) REFERENCES Silver.LIS_OrdenLaboratorio(OrdenLISID)
);
GO

-- ---------- 09_silver_PACS.ktr ----------
CREATE TABLE Silver.PACS_EstudioDICOM (
    EstudioPACSID            VARCHAR(20)     NOT NULL,
    PacienteHISID              VARCHAR(20)     NULL,
    EpisodioHISID                VARCHAR(20)     NULL,
    Modalidad                      VARCHAR(10)     NULL,
    RegionAnatomica                  NVARCHAR(80)    NULL,
    FechaEstudio                       DATETIME2(0)    NULL,
    EstadoInforme                        NVARCHAR(30)    NULL,
    TamanoMB                               DECIMAL(10,2)   NULL,
    FechaCargaSilver                         DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_PACS_EstudioDICOM PRIMARY KEY CLUSTERED (EstudioPACSID)
);
GO

-- ---------- 10_silver_IOT.ktr ----------
-- (SesionIOTID no se propaga con relación de sesión a Gold — ver nota de diseño)
CREATE TABLE Silver.IOT_SesionMonitorizacionUCI (
    SesionIOTID              VARCHAR(20)     NOT NULL,
    PacienteHISID              VARCHAR(20)     NULL,
    EpisodioHISID                 VARCHAR(20)     NULL,
    DispositivoID                    VARCHAR(40)     NULL,
    ModeloDispositivo                  NVARCHAR(80)    NULL,
    Cama                                 NVARCHAR(20)    NULL,
    FechaInicio                            DATETIME2(0)    NULL,
    FechaFin                                 DATETIME2(0)    NULL,
    FechaCargaSilver                           DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_IOT_Sesion PRIMARY KEY CLUSTERED (SesionIOTID)
);
GO

-- Payload JSON parseado manualmente vía "Modified JavaScript Value" + JSON.parse()
-- (el step nativo "JSON Input" de PDI 10.2 fallaba con "source from field")
CREATE TABLE Silver.IOT_EventoSignosVitalesMQTT (
    EventoIOTID                 BIGINT          NOT NULL,
    SesionIOTID                    VARCHAR(20)     NOT NULL,
    FechaEvento                       DATETIME2(0)    NULL,
    HeartRate                            INT             NULL,
    SpO2                                   INT             NULL,
    PresionSistolica                         INT             NULL,
    PresionDiastolica                          INT             NULL,
    FrecuenciaRespiratoria                       INT             NULL,
    Temperatura                                    DECIMAL(4,1)    NULL,
    Alarma                                           NVARCHAR(30)    NULL,
    EsAlarmaCritica                                    BIT             NOT NULL DEFAULT 0,
    FechaCargaSilver                                     DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_IOT_Evento PRIMARY KEY CLUSTERED (EventoIOTID),
    CONSTRAINT FK_Silver_Evento_Sesion FOREIGN KEY (SesionIOTID) REFERENCES Silver.IOT_SesionMonitorizacionUCI(SesionIOTID)
);
GO

-- ---------- 11_silver_SAP.ktr ----------
CREATE TABLE Silver.SAP_DocumentoFinanciero (
    DocumentoSAPID              VARCHAR(20)     NOT NULL,
    PacienteHISID                  VARCHAR(20)     NULL,
    EpisodioHISID                     VARCHAR(20)     NULL,
    FechaEmision                        DATE            NULL,
    Prevision                             NVARCHAR(30)    NULL,
    MontoNeto                               DECIMAL(14,2)   NULL,
    EstadoPago                                NVARCHAR(30)    NULL,
    FechaCargaSilver                            DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_SAP_Documento PRIMARY KEY CLUSTERED (DocumentoSAPID)
);
GO

CREATE TABLE Silver.SAP_DetalleDocumento (
    DetalleSAPID                 INT             NOT NULL,
    DocumentoSAPID                  VARCHAR(20)     NOT NULL,
    CodigoPrestacion                   VARCHAR(30)     NULL,
    Descripcion                          NVARCHAR(200)   NULL,
    Cantidad                               DECIMAL(10,2)   NULL,
    PrecioUnitario                           DECIMAL(14,2)   NULL,
    TotalLinea                                 DECIMAL(14,2)   NULL,
    FechaCargaSilver                             DATETIME2(7)    NOT NULL,
    CONSTRAINT PK_Silver_SAP_Detalle PRIMARY KEY CLUSTERED (DetalleSAPID),
    CONSTRAINT FK_Silver_Detalle_Documento FOREIGN KEY (DocumentoSAPID) REFERENCES Silver.SAP_DocumentoFinanciero(DocumentoSAPID)
);
GO


/* ============================================================================
   ============================================================================
   ZONA GOLD — MODELO DIMENSIONAL: CONSTELACIÓN DE HECHOS (Criterios 4 y 5)
   ============================================================================
   ============================================================================
   8 tablas de dimensión + 6 tablas de hechos = 14 tablas.
   Surrogate keys de dimensiones: IDENTITY(1,1) en el DDL de SQL Server.
   Resolución de FK en hechos: steps "Stream lookup" encadenados en Pentaho
   (no "Database lookup", por un bug del driver jTDS con comparaciones de
   fecha). Integridad referencial validada: 0 filas huérfanas.
   ============================================================================ */

-- ================= DIMENSIONES (12_gold_dimensiones.ktr) =================

CREATE TABLE Gold.Dim_Paciente (
    PacienteSK       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PacienteHISID    VARCHAR(20)       NOT NULL,
    RUN_Hash         VARCHAR(64)       NOT NULL,
    Iniciales        VARCHAR(10)       NULL,
    Sexo             CHAR(1)           NULL,
    EdadAnios        INT               NULL,
    Comuna           NVARCHAR(80)      NULL,
    Region           NVARCHAR(80)      NULL,
    Prevision        NVARCHAR(30)      NULL
);
GO

CREATE TABLE Gold.Dim_Profesional (
    ProfesionalSK     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProfesionalHISID  VARCHAR(20)       NOT NULL,
    NombreCompleto    NVARCHAR(120)     NULL,
    Especialidad      NVARCHAR(80)      NULL,
    SedeBase          NVARCHAR(60)      NULL
);
GO

CREATE TABLE Gold.Dim_Servicio (
    ServicioSK        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Sede              NVARCHAR(60)      NULL,
    Servicio          NVARCHAR(80)      NULL,
    TipoAtencion      NVARCHAR(40)      NULL
);
GO

CREATE TABLE Gold.Dim_Tiempo (
    TiempoSK          INT               NOT NULL PRIMARY KEY,  -- = CAST(FORMAT(fecha,'yyyyMMdd') AS INT)
    Fecha             DATE              NOT NULL,
    Dia               INT               NULL,
    DiaSemana         NVARCHAR(20)      NULL,
    Mes               INT               NULL,
    NombreMes         NVARCHAR(20)      NULL,
    Trimestre         INT               NULL,
    Anio              INT               NULL
);
GO

CREATE TABLE Gold.Dim_Diagnostico (
    DiagnosticoSK      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CodigoCIE10        VARCHAR(10)       NOT NULL,
    DescripcionCIE10   NVARCHAR(200)     NULL,
    TipoDiagnostico    NVARCHAR(30)      NULL
);
GO

CREATE TABLE Gold.Dim_Prestacion (
    PrestacionSK       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CodigoPrestacion   VARCHAR(30)       NOT NULL,
    Descripcion        NVARCHAR(200)     NULL
);
GO

CREATE TABLE Gold.Dim_Dispositivo (
    DispositivoSK       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    DispositivoID       VARCHAR(40)       NOT NULL,
    ModeloDispositivo   NVARCHAR(80)      NULL,
    Cama                NVARCHAR(20)      NULL
);
GO

CREATE TABLE Gold.Dim_Modalidad (
    ModalidadSK          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Modalidad            VARCHAR(10)       NOT NULL,
    DescripcionModalidad NVARCHAR(80)      NULL
);
GO

-- ================= TABLAS DE HECHOS (13 a 19) =================

-- 13_gold_fact_atenciones — grano: una atención de un paciente en un episodio
CREATE TABLE Gold.Fact_Atenciones (
    AtencionSK            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EpisodioHISID         VARCHAR(20)       NOT NULL,
    PacienteSK            INT               NOT NULL,
    ProfesionalSK         INT               NOT NULL,
    ServicioSK            INT               NOT NULL,
    TiempoSK              INT               NOT NULL,
    DuracionHoras         DECIMAL(10,2)     NULL,
    CantidadDiagnosticos  INT               NOT NULL DEFAULT 0,
    CONSTRAINT FK_FactAtenciones_Paciente    FOREIGN KEY (PacienteSK)    REFERENCES Gold.Dim_Paciente(PacienteSK),
    CONSTRAINT FK_FactAtenciones_Profesional FOREIGN KEY (ProfesionalSK) REFERENCES Gold.Dim_Profesional(ProfesionalSK),
    CONSTRAINT FK_FactAtenciones_Servicio    FOREIGN KEY (ServicioSK)    REFERENCES Gold.Dim_Servicio(ServicioSK),
    CONSTRAINT FK_FactAtenciones_Tiempo      FOREIGN KEY (TiempoSK)      REFERENCES Gold.Dim_Tiempo(TiempoSK)
);
GO

-- 14_gold_fact_laboratorio — grano: un resultado de examen de un paciente
CREATE TABLE Gold.Fact_Laboratorio (
    ResultadoLabSK      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ResultadoLISID      INT               NOT NULL,
    PacienteSK           INT               NOT NULL,
    TiempoSK              INT               NOT NULL,
    ResultadoValor         DECIMAL(12,3)     NULL,
    NombreExamen             NVARCHAR(120)     NULL,
    RangoReferencia            NVARCHAR(60)      NULL,
    FlagResultado                NVARCHAR(20)      NULL,
    CONSTRAINT FK_FactLaboratorio_Paciente FOREIGN KEY (PacienteSK) REFERENCES Gold.Dim_Paciente(PacienteSK),
    CONSTRAINT FK_FactLaboratorio_Tiempo   FOREIGN KEY (TiempoSK)   REFERENCES Gold.Dim_Tiempo(TiempoSK)
);
GO

-- 15_gold_fact_financiero — grano: un detalle (línea) de documento de facturación
CREATE TABLE Gold.Fact_Financiero (
    DetalleFinSK         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    DetalleSAPID          INT               NOT NULL,
    PacienteSK             INT               NOT NULL,
    PrestacionSK             INT               NOT NULL,
    TiempoSK                   INT               NOT NULL,
    Cantidad                     DECIMAL(10,2)     NULL,
    PrecioUnitario                  DECIMAL(14,2)     NULL,
    TotalLinea                        DECIMAL(14,2)     NULL,
    CONSTRAINT FK_FactFinanciero_Paciente    FOREIGN KEY (PacienteSK)    REFERENCES Gold.Dim_Paciente(PacienteSK),
    CONSTRAINT FK_FactFinanciero_Prestacion  FOREIGN KEY (PrestacionSK)  REFERENCES Gold.Dim_Prestacion(PrestacionSK),
    CONSTRAINT FK_FactFinanciero_Tiempo      FOREIGN KEY (TiempoSK)      REFERENCES Gold.Dim_Tiempo(TiempoSK)
);
GO

-- 16_gold_dim_modalidad ya incluida arriba (Dim_Modalidad)

-- 17_gold_fact_signos_vitales_uci — grano: un evento de monitoreo (cada 30 seg)
CREATE TABLE Gold.Fact_SignosVitalesUCI (
    SignoVitalSK           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EventoIOTID              BIGINT            NOT NULL,
    PacienteSK                 INT               NOT NULL,
    TiempoSK                     INT               NOT NULL,
    DispositivoSK                  INT               NOT NULL,
    HeartRate                        INT               NULL,
    SpO2                               INT               NULL,
    PresionSistolica                     INT               NULL,
    PresionDiastolica                      INT               NULL,
    FrecuenciaRespiratoria                    INT               NULL,
    Temperatura                                 DECIMAL(4,1)      NULL,
    Alarma                                        NVARCHAR(30)      NULL,
    EsAlarmaCritica                                 BIT               NOT NULL DEFAULT 0,
    CONSTRAINT FK_FactSignosVitales_Paciente    FOREIGN KEY (PacienteSK)    REFERENCES Gold.Dim_Paciente(PacienteSK),
    CONSTRAINT FK_FactSignosVitales_Tiempo      FOREIGN KEY (TiempoSK)      REFERENCES Gold.Dim_Tiempo(TiempoSK),
    CONSTRAINT FK_FactSignosVitales_Dispositivo FOREIGN KEY (DispositivoSK) REFERENCES Gold.Dim_Dispositivo(DispositivoSK)
);
-- NOTA DE DISEÑO: no incluye SesionIOTID (no se propagó desde Silver);
-- el análisis solo puede agregarse por PacienteSK, no por sesión individual.
GO

-- 18_gold_fact_estudios_pacs — grano: un estudio DICOM
CREATE TABLE Gold.Fact_EstudiosPACS (
    EstudioPACSSK          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EstudioPACSID             VARCHAR(20)       NOT NULL,
    PacienteSK                  INT               NOT NULL,
    TiempoSK                      INT               NOT NULL,
    ModalidadSK                     INT               NOT NULL,
    RegionAnatomica                   NVARCHAR(80)      NULL,
    EstadoInforme                       NVARCHAR(30)      NULL,
    TamanoMB                              DECIMAL(10,2)     NULL,
    CONSTRAINT FK_FactEstudiosPACS_Paciente  FOREIGN KEY (PacienteSK)  REFERENCES Gold.Dim_Paciente(PacienteSK),
    CONSTRAINT FK_FactEstudiosPACS_Tiempo    FOREIGN KEY (TiempoSK)    REFERENCES Gold.Dim_Tiempo(TiempoSK),
    CONSTRAINT FK_FactEstudiosPACS_Modalidad FOREIGN KEY (ModalidadSK) REFERENCES Gold.Dim_Modalidad(ModalidadSK)
);
GO

-- 19_gold_dim_dispositivo ya incluida arriba (Dim_Dispositivo)

-- Fact_PrediccionDeterioro — generada por el modelo de Machine Learning
-- (Actividad 2, Criterio 8), cargada desde Python vía modelo_deterioro_uci.py.
-- Grano: una predicción de riesgo por paciente.
CREATE TABLE Gold.Fact_PrediccionDeterioro (
    PrediccionSK           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PacienteSK              INT               NOT NULL,
    ProbabilidadDeterioro    DECIMAL(5,4)      NOT NULL,
    PrediccionClase            INT               NOT NULL,
    FechaCalculo                 DATETIME2         NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_PrediccionDeterioro_Paciente FOREIGN KEY (PacienteSK) REFERENCES Gold.Dim_Paciente(PacienteSK)
);
GO


/* ============================================================================
   ============================================================================
   QUERIES DE EVIDENCIA — VALIDACIÓN Y CONTEOS
   ============================================================================
   ============================================================================
   Las mismas consultas usadas para verificar el proyecto durante el
   desarrollo. Resultados esperados documentados en el informe.
   ============================================================================ */

-- 1) Última corrida de validación de fuentes (11 filas esperadas)
SELECT *
FROM dbo.LogValidacionFuentes
WHERE FechaValidacion = (SELECT MAX(FechaValidacion) FROM dbo.LogValidacionFuentes)
ORDER BY TablaOrigen;
GO

-- 2) Conteos Bronze vs Origen (0 discrepancias esperadas)
SELECT 'HIS_Paciente' AS Tabla,
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.HIS.Paciente) AS Origen,
    (SELECT COUNT(*) FROM Bronze.HIS_Paciente) AS Bronze
UNION ALL
SELECT 'HIS_Profesional',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.HIS.Profesional),
    (SELECT COUNT(*) FROM Bronze.HIS_Profesional)
UNION ALL
SELECT 'HIS_EpisodioClinico',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.HIS.EpisodioClinico),
    (SELECT COUNT(*) FROM Bronze.HIS_EpisodioClinico)
UNION ALL
SELECT 'HIS_DiagnosticoEpisodio',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.HIS.DiagnosticoEpisodio),
    (SELECT COUNT(*) FROM Bronze.HIS_DiagnosticoEpisodio)
UNION ALL
SELECT 'LIS_OrdenLaboratorio',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.LIS.OrdenLaboratorio),
    (SELECT COUNT(*) FROM Bronze.LIS_OrdenLaboratorio)
UNION ALL
SELECT 'LIS_ResultadoLaboratorio',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.LIS.ResultadoLaboratorio),
    (SELECT COUNT(*) FROM Bronze.LIS_ResultadoLaboratorio)
UNION ALL
SELECT 'PACS_EstudioDICOM',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.PACS.EstudioDICOM),
    (SELECT COUNT(*) FROM Bronze.PACS_EstudioDICOM)
UNION ALL
SELECT 'IOT_SesionMonitorizacionUCI',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.IOT.SesionMonitorizacionUCI),
    (SELECT COUNT(*) FROM Bronze.IOT_SesionMonitorizacionUCI)
UNION ALL
SELECT 'IOT_EventoSignosVitalesMQTT',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.IOT.EventoSignosVitalesMQTT),
    (SELECT COUNT(*) FROM Bronze.IOT_EventoSignosVitalesMQTT)
UNION ALL
SELECT 'SAP_DocumentoFinanciero',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.SAP.DocumentoFinanciero),
    (SELECT COUNT(*) FROM Bronze.SAP_DocumentoFinanciero)
UNION ALL
SELECT 'SAP_DetalleDocumento',
    (SELECT COUNT(*) FROM MedCentro_Fuentes_Simuladas_1000.SAP.DetalleDocumento),
    (SELECT COUNT(*) FROM Bronze.SAP_DetalleDocumento)
ORDER BY Tabla;
GO

-- 3) Conteos Silver vs Bronze (0 discrepancias esperadas)
SELECT 'HIS_Paciente' AS Tabla, (SELECT COUNT(*) FROM Bronze.HIS_Paciente) AS Bronze, (SELECT COUNT(*) FROM Silver.HIS_Paciente) AS Silver
UNION ALL SELECT 'HIS_Profesional', (SELECT COUNT(*) FROM Bronze.HIS_Profesional), (SELECT COUNT(*) FROM Silver.HIS_Profesional)
UNION ALL SELECT 'HIS_EpisodioClinico', (SELECT COUNT(*) FROM Bronze.HIS_EpisodioClinico), (SELECT COUNT(*) FROM Silver.HIS_EpisodioClinico)
UNION ALL SELECT 'HIS_DiagnosticoEpisodio', (SELECT COUNT(*) FROM Bronze.HIS_DiagnosticoEpisodio), (SELECT COUNT(*) FROM Silver.HIS_DiagnosticoEpisodio)
UNION ALL SELECT 'LIS_OrdenLaboratorio', (SELECT COUNT(*) FROM Bronze.LIS_OrdenLaboratorio), (SELECT COUNT(*) FROM Silver.LIS_OrdenLaboratorio)
UNION ALL SELECT 'LIS_ResultadoLaboratorio', (SELECT COUNT(*) FROM Bronze.LIS_ResultadoLaboratorio), (SELECT COUNT(*) FROM Silver.LIS_ResultadoLaboratorio)
UNION ALL SELECT 'PACS_EstudioDICOM', (SELECT COUNT(*) FROM Bronze.PACS_EstudioDICOM), (SELECT COUNT(*) FROM Silver.PACS_EstudioDICOM)
UNION ALL SELECT 'IOT_SesionMonitorizacionUCI', (SELECT COUNT(*) FROM Bronze.IOT_SesionMonitorizacionUCI), (SELECT COUNT(*) FROM Silver.IOT_SesionMonitorizacionUCI)
UNION ALL SELECT 'IOT_EventoSignosVitalesMQTT', (SELECT COUNT(*) FROM Bronze.IOT_EventoSignosVitalesMQTT), (SELECT COUNT(*) FROM Silver.IOT_EventoSignosVitalesMQTT)
UNION ALL SELECT 'SAP_DocumentoFinanciero', (SELECT COUNT(*) FROM Bronze.SAP_DocumentoFinanciero), (SELECT COUNT(*) FROM Silver.SAP_DocumentoFinanciero)
UNION ALL SELECT 'SAP_DetalleDocumento', (SELECT COUNT(*) FROM Bronze.SAP_DetalleDocumento), (SELECT COUNT(*) FROM Silver.SAP_DetalleDocumento)
ORDER BY Tabla;
GO

-- 4) Anonimización: mismo paciente, Bronze vs Silver
SELECT TOP 3 PacienteHISID, RUN, Nombres, Apellidos, Telefono, Email FROM Bronze.HIS_Paciente ORDER BY PacienteHISID;
SELECT TOP 3 PacienteHISID, RUN_Hash, Iniciales FROM Silver.HIS_Paciente ORDER BY PacienteHISID;
GO

-- 5) Integridad referencial en Gold: 0 filas huérfanas esperadas
SELECT 'Fact_Atenciones -> Dim_Paciente' AS Verificacion, COUNT(*) AS Huerfanas
FROM Gold.Fact_Atenciones f LEFT JOIN Gold.Dim_Paciente d ON f.PacienteSK = d.PacienteSK WHERE d.PacienteSK IS NULL
UNION ALL
SELECT 'Fact_Atenciones -> Dim_Profesional', COUNT(*)
FROM Gold.Fact_Atenciones f LEFT JOIN Gold.Dim_Profesional d ON f.ProfesionalSK = d.ProfesionalSK WHERE d.ProfesionalSK IS NULL
UNION ALL
SELECT 'Fact_Atenciones -> Dim_Servicio', COUNT(*)
FROM Gold.Fact_Atenciones f LEFT JOIN Gold.Dim_Servicio d ON f.ServicioSK = d.ServicioSK WHERE d.ServicioSK IS NULL
UNION ALL
SELECT 'Fact_Atenciones -> Dim_Tiempo', COUNT(*)
FROM Gold.Fact_Atenciones f LEFT JOIN Gold.Dim_Tiempo d ON f.TiempoSK = d.TiempoSK WHERE d.TiempoSK IS NULL
UNION ALL
SELECT 'Fact_Laboratorio -> Dim_Paciente', COUNT(*)
FROM Gold.Fact_Laboratorio f LEFT JOIN Gold.Dim_Paciente d ON f.PacienteSK = d.PacienteSK WHERE d.PacienteSK IS NULL
UNION ALL
SELECT 'Fact_Financiero -> Dim_Paciente', COUNT(*)
FROM Gold.Fact_Financiero f LEFT JOIN Gold.Dim_Paciente d ON f.PacienteSK = d.PacienteSK WHERE d.PacienteSK IS NULL;
GO

-- 6) Conteos finales de todas las tablas Gold
SELECT 'Dim_Diagnostico' AS Tabla, COUNT(*) AS Registros FROM Gold.Dim_Diagnostico
UNION ALL SELECT 'Dim_Dispositivo', COUNT(*) FROM Gold.Dim_Dispositivo
UNION ALL SELECT 'Dim_Modalidad', COUNT(*) FROM Gold.Dim_Modalidad
UNION ALL SELECT 'Dim_Paciente', COUNT(*) FROM Gold.Dim_Paciente
UNION ALL SELECT 'Dim_Prestacion', COUNT(*) FROM Gold.Dim_Prestacion
UNION ALL SELECT 'Dim_Profesional', COUNT(*) FROM Gold.Dim_Profesional
UNION ALL SELECT 'Dim_Servicio', COUNT(*) FROM Gold.Dim_Servicio
UNION ALL SELECT 'Dim_Tiempo', COUNT(*) FROM Gold.Dim_Tiempo
UNION ALL SELECT 'Fact_Atenciones', COUNT(*) FROM Gold.Fact_Atenciones
UNION ALL SELECT 'Fact_EstudiosPACS', COUNT(*) FROM Gold.Fact_EstudiosPACS
UNION ALL SELECT 'Fact_Financiero', COUNT(*) FROM Gold.Fact_Financiero
UNION ALL SELECT 'Fact_Laboratorio', COUNT(*) FROM Gold.Fact_Laboratorio
UNION ALL SELECT 'Fact_PrediccionDeterioro', COUNT(*) FROM Gold.Fact_PrediccionDeterioro
UNION ALL SELECT 'Fact_SignosVitalesUCI', COUNT(*) FROM Gold.Fact_SignosVitalesUCI
ORDER BY Tabla;
GO

-- 7) Predicciones de Machine Learning (Actividad 2), ordenadas por riesgo
SELECT TOP 20 *
FROM Gold.Fact_PrediccionDeterioro
ORDER BY ProbabilidadDeterioro DESC;
GO

/* ============================================================================
   FIN DEL SCRIPT DE RESUMEN
   ============================================================================ */
