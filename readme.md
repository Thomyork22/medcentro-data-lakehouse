# 🏥 Clínica MedCentro S.A. - Data Lakehouse & Machine Learning

![Arquitectura](https://img.shields.io/badge/Architecture-Medallion-blue)
![Stack](https://img.shields.io/badge/Stack-Pentaho%20%7C%20SQL%20Server%20%7C%20Python%20%7C%20PowerBI-success)
![Cumplimiento](https://img.shields.io/badge/Cumplimiento-Ley%20N%C2%B0%2021.541-critical)

## 📌 Contexto del Proyecto
Este proyecto es una solución integral de Ingeniería de Datos y Analítica Avanzada diseñada para la **Clínica MedCentro S.A.** El desafío principal consistió en unificar 5 sistemas de información clínicos y financieros (HIS, LIS, PACS, IoT UCI y SAP ERP) que operaban como silos de datos, consolidándolos en una arquitectura moderna, segura y escalable.

La solución abarca todo el ciclo de vida del dato: desde la orquestación automatizada (ETL) y la persistencia estructurada, hasta la predicción clínica (Machine Learning) y la toma de decisiones gerenciales (Business Intelligence).

## 🏗️ Arquitectura de Datos: Enfoque Medallón (Lakehouse)
Se optó por una arquitectura **Data Lakehouse (Zonas Bronze, Silver, Gold)** alojada en SQL Server, en contraposición a un Data Warehouse tradicional, para soportar datos estructurados y semi-estructurados (como señales MQTT de UCI).

1. **Zona Bronze (Raw):** 
   * Principio de *schema-on-write*. Las tablas replican la estructura original sin restricciones de integridad. 
   * Cargas idempotentes (Truncate/Insert) asegurando la no duplicidad de registros y con columnas de auditoría embebidas.
2. **Zona Silver (Cleansed & Anonymized):** 
   * Datos normalizados y con Primary Keys establecidas.
   * **Gobernanza de Datos:** Cumplimiento estricto de la **Ley N° 21.541 (Protección de Datos en Salud)** mediante anonimización real. Se aplicó un hash **SHA-256 irreversible** a los RUT de los pacientes, ocultamiento parcial de nombres y eliminación de datos de contacto directo.
3. **Zona Gold (Dimensional):** 
   * Modelo tipo **Constelación de Hechos**.
   * Estructurada en 8 Dimensiones (con llaves sustitutas `IDENTITY`) y 6 tablas de Hechos, resolviendo la integridad referencial en el motor de base de datos.

## ⚙️ Pipeline ETL: Pentaho Data Integration
Para la automatización e integración de datos se definió como regla de diseño estricta: **Cero código SQL para transformaciones (No Stored Procedures)**. Esto protege la flexibilidad de la capa Bronze.

* Todo el flujo fue desarrollado de manera visual y modular a través de **17 transformaciones (.ktr)**.
* La orquestación completa corre bajo un **Job Maestro (.kjb)** que valida las 5 fuentes en origen, y ejecuta secuencialmente las cargas a Bronze, Silver y Gold.
* Posee **Manejo de Errores Centralizado**, deteniendo el flujo ante fallos para evitar la propagación de anomalías hacia la capa analítica.

## 🤖 Machine Learning: Alerta Temprana en UCI
Para otorgar valor predictivo a los datos clínicos (Zona Gold), se entrenó un modelo de Machine Learning en **Python (Scikit-Learn)** para predecir el deterioro temprano en pacientes críticos.

* **Preparación:** Prevención de *Data Leakage*. Imputación de nulos (`SimpleImputer`) y escalado (`StandardScaler`) de variables vitales (SpO2, FC, Presión Arterial).
* **Algoritmo:** Regresión Logística con balanceo paramétrico (`class_weight="balanced"`).
* **Métricas Clave:** El modelo priorizó la sensibilidad médica, logrando un **Recall de 1.000**, garantizando que ningún evento de deterioro real pasara desapercibido como falso negativo.
* **Integración:** Las probabilidades de riesgo se escribieron de vuelta en la base de datos analítica (`Gold.Fact_PrediccionDeterioro`).

## 📊 Business Intelligence
Los informes de toma de decisiones se desarrollaron en **Power BI**, conectados en modo *Import* directamente a la Constelación de Hechos (Zona Gold).

* Se definieron métricas DAX avanzadas (usando `CALCULATE`, filtros de contexto, variables) para evaluar el volumen de atenciones, la facturación bruta, alertas críticas de IoT y cobertura de datos.
* Se incorporaron segmentadores dinámicos que interactúan con las predicciones del modelo de Machine Learning, identificando pacientes de "Alto Riesgo".

## 📁 Estructura del Repositorio
```text
/
├── pentaho/                  # Jobs (.kjb) y Transformaciones (.ktr) ETL
├── Informes/                 # Documentación y justificación técnica (PDF/Docx)
├── MedCentro_PowerBI.pbix    # Dashboards e informes DAX
├── modelo_deterioro_uci.py   # Script ML (Scikit-Learn)
└── Script_Resumen_DDL.sql    # DDL del Data Lakehouse (Bronze/Silver/Gold)