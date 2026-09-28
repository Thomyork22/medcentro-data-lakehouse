"""
Modelo de predicción de deterioro clínico UCI - MedCentro S.A.
Actividad 2 - Machine Learning

Este script:
1. Extrae datos de Gold.Fact_SignosVitalesUCI agregados por paciente
2. Entrena un modelo de regresión logística para predecir riesgo de deterioro
3. Evalúa el modelo (matriz de confusión, precisión, recall, F1)
4. Genera predicciones y las carga a Gold.Fact_PrediccionDeterioro en SQL Server

Requiere la variable de entorno MSSQL_SA_PASSWORD con la contraseña del usuario 'sa'.
"""

import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

import pandas as pd
import pyodbc
from dotenv import load_dotenv

load_dotenv()
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, precision_score, recall_score, f1_score, accuracy_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

# ============================================================
# CONFIGURACIÓN DE CONEXIÓN
# ============================================================
SERVER = r"localhost\SQL"
DATABASE = "MedCentro_Lakehouse"
USERNAME = "sa"
PASSWORD = os.environ.get("MSSQL_SA_PASSWORD")
if not PASSWORD:
    sys.exit("Error: defina la variable de entorno MSSQL_SA_PASSWORD con la contraseña del usuario 'sa'.")

conn_str = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    f"TrustServerCertificate=yes;"
)

print("Conectando a SQL Server...")
conn = pyodbc.connect(conn_str)
print("Conexión exitosa.\n")

# ============================================================
# PASO 1: EXTRAER Y AGREGAR DATOS POR PACIENTE
# ============================================================
query = """
SELECT
    PacienteSK,
    AVG(CAST(HeartRate AS FLOAT)) AS HeartRate_Promedio,
    MAX(HeartRate) AS HeartRate_Maximo,
    MIN(HeartRate) AS HeartRate_Minimo,
    AVG(CAST(SpO2 AS FLOAT)) AS SpO2_Promedio,
    MAX(SpO2) AS SpO2_Maximo,
    MIN(SpO2) AS SpO2_Minimo,
    AVG(CAST(PresionSistolica AS FLOAT)) AS PresionSistolica_Promedio,
    MAX(PresionSistolica) AS PresionSistolica_Maxima,
    MIN(PresionSistolica) AS PresionSistolica_Minima,
    AVG(CAST(PresionDiastolica AS FLOAT)) AS PresionDiastolica_Promedio,
    MAX(PresionDiastolica) AS PresionDiastolica_Maxima,
    MIN(PresionDiastolica) AS PresionDiastolica_Minima,
    AVG(CAST(Temperatura AS FLOAT)) AS Temperatura_Promedio,
    MAX(Temperatura) AS Temperatura_Maxima,
    MIN(Temperatura) AS Temperatura_Minima,
    AVG(CAST(FrecuenciaRespiratoria AS FLOAT)) AS FrecResp_Promedio,
    MAX(CAST(EsAlarmaCritica AS INT)) AS HuboAlarmaCritica
FROM Gold.Fact_SignosVitalesUCI
GROUP BY PacienteSK;
"""

print("Extrayendo y agregando datos por paciente...")
df = pd.read_sql(query, conn)
print(f"Dataset extraído: {df.shape[0]} pacientes, {df.shape[1]} columnas\n")

# ============================================================
# PASO 2: ENTRENAR EL MODELO
# ============================================================
# Variable objetivo: si el paciente tuvo al menos una alarma crítica
target = "HuboAlarmaCritica"

# Features: columnas numéricas de signos vitales (excluye PacienteSK y el target)
feature_cols = [c for c in df.columns if c not in ["PacienteSK", target]]

X = df[feature_cols]
y = df[target]

print(f"Distribución de la variable objetivo:\n{y.value_counts()}\n")

# Pipeline de imputación (por si hay pacientes con NULL en algún agregado) + escalado.
# El scaler se ajusta SOLO con el set de entrenamiento (fit dentro del Pipeline en X_train)
# para no filtrar información del set de prueba hacia el entrenamiento.
pipeline = Pipeline(steps=[
    ("imputer", SimpleImputer(strategy="median")),
    ("scaler", StandardScaler()),
    ("classifier", LogisticRegression(max_iter=1000, class_weight="balanced", random_state=42)),
])

stratify_arg = y if y.value_counts().min() >= 2 else None
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.25, random_state=42, stratify=stratify_arg
)

print("Entrenando modelo de regresión logística...")
pipeline.fit(X_train, y_train)
print("Modelo entrenado.\n")

# ============================================================
# PASO 3: EVALUAR EL MODELO
# ============================================================
y_pred = pipeline.predict(X_test)

print("=" * 50)
print("EVALUACIÓN DEL MODELO")
print("=" * 50)
print(f"Exactitud (Accuracy):  {accuracy_score(y_test, y_pred):.3f}")
print(f"Precisión (Precision): {precision_score(y_test, y_pred, zero_division=0):.3f}")
print(f"Sensibilidad (Recall): {recall_score(y_test, y_pred, zero_division=0):.3f}")
print(f"F1-Score:              {f1_score(y_test, y_pred, zero_division=0):.3f}")
print("\nMatriz de Confusión:")
cm = confusion_matrix(y_test, y_pred)
print(f"                 Predicho: No    Predicho: Sí")
print(f"Real: No         {cm[0][0]:<15}{cm[0][1]}")
print(f"Real: Sí         {cm[1][0]:<15}{cm[1][1]}")
print("=" * 50 + "\n")

# ============================================================
# PASO 4: GENERAR PREDICCIONES PARA TODOS LOS PACIENTES
# ============================================================
# Se reentrena sobre el 100% de los datos (mismo pipeline, misma configuración)
# para producir el modelo final que puntúa a todos los pacientes.
print("Reentrenando sobre todo el dataset para generar predicciones finales...")
pipeline.fit(X, y)

print("Generando predicciones para todos los pacientes...")
probabilidades = pipeline.predict_proba(X)[:, 1]  # Probabilidad de clase "1" (deterioro)
predicciones_clase = pipeline.predict(X)

df_predicciones = pd.DataFrame({
    "PacienteSK": df["PacienteSK"],
    "ProbabilidadDeterioro": probabilidades,
    "PrediccionClase": predicciones_clase
})

print(df_predicciones.sort_values("ProbabilidadDeterioro", ascending=False).head(10))
print()

# ============================================================
# PASO 5: CREAR TABLA (SI NO EXISTE) Y CARGAR PREDICCIONES
# ============================================================
cursor = conn.cursor()
cursor.fast_executemany = True

print("Creando tabla Gold.Fact_PrediccionDeterioro (si no existe)...")
cursor.execute("""
IF OBJECT_ID('Gold.Fact_PrediccionDeterioro', 'U') IS NOT NULL
    DROP TABLE Gold.Fact_PrediccionDeterioro;

CREATE TABLE Gold.Fact_PrediccionDeterioro (
    PrediccionSK INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PacienteSK INT NOT NULL,
    ProbabilidadDeterioro DECIMAL(5,4) NOT NULL,
    PrediccionClase INT NOT NULL,
    FechaCalculo DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_PrediccionDeterioro_Paciente FOREIGN KEY (PacienteSK) REFERENCES Gold.Dim_Paciente(PacienteSK)
);
""")
conn.commit()
print("Tabla creada.\n")

print("Cargando predicciones...")
params = list(
    df_predicciones[["PacienteSK", "ProbabilidadDeterioro", "PrediccionClase"]]
    .itertuples(index=False, name=None)
)
cursor.executemany(
    """
    INSERT INTO Gold.Fact_PrediccionDeterioro (PacienteSK, ProbabilidadDeterioro, PrediccionClase)
    VALUES (?, ?, ?)
    """,
    params,
)
conn.commit()
print(f"{len(df_predicciones)} predicciones cargadas exitosamente en Gold.Fact_PrediccionDeterioro.\n")

# ============================================================
# RESUMEN FINAL
# ============================================================
print("=" * 50)
print("RESUMEN FINAL")
print("=" * 50)
print(f"Total de pacientes analizados: {len(df)}")
print(f"Pacientes con predicción de alto riesgo (clase=1): {(df_predicciones['PrediccionClase'] == 1).sum()}")
print(f"F1-Score del modelo (sobre el set de prueba): {f1_score(y_test, y_pred, zero_division=0):.3f}")
print("Predicciones disponibles en: Gold.Fact_PrediccionDeterioro")
print("=" * 50)

conn.close()
print("\nProceso completado.")
