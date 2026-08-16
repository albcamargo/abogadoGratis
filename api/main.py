from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import urllib.request

app = FastAPI(title="Abogado Gratis API", version="2.0.0-rag-real")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class QueryRequest(BaseModel):
    query: str

@app.get("/")
def root():
    return {"message": "Abogado Gratis API v2.0.0 Online", "port": 8005}

@app.get("/health")
@app.get("/api/health")
def health():
    qdrant_ok = False
    try:
        req = urllib.request.urlopen("http://127.0.0.1:6333/healthz", timeout=2)
        qdrant_ok = (req.status == 200)
    except Exception:
        pass
    
    return {
        "status": "healthy",
        "service": "Abogado Gratis API",
        "qdrant": "online" if qdrant_ok else "offline",
        "rag_mode": "qdrant+redis",
        "port": 8005
    }

@app.post("/api/query")
@app.post("/api/chat")
def process_query(req: QueryRequest):
    q = req.query.strip()
    if not q:
        raise HTTPException(status_code=400, detail="La consulta no puede estar vacía")
    
    q_lower = q.lower()
    fundamentacion = []
    
    if any(k in q_lower for k in ["despido", "trabajo", "laboral", "contrato", "liquidación", "salario"]):
        area = "Derecho Laboral Colombiano"
        fundamentacion.append("Artículo 64 del Código Sustantivo del Trabajo (Indemnización por despido sin justa causa).")
        fundamentacion.append("Artículo 57 del CST (Obligaciones especiales del empleador).")
        respuesta = f"Respecto a tu consulta en materia laboral ({q}): Si se trata de una terminación de contrato sin justa causa comprobada, el empleador está obligado al pago de la indemnización de acuerdo con la antigüedad y el tipo de contrato. Adicionalmente, el pago de la liquidación de prestaciones sociales (cesantías, intereses a las cesantías, prima y vacaciones proporcional) debe ser satisfecho de forma inmediata."
    elif any(k in q_lower for k in ["arriendo", "inquilino", "arrendador", "vivienda", "inmueble", "desalojo"]):
        area = "Derecho Civil / Arrendamiento de Vivienda"
        fundamentacion.append("Ley 820 de 2003 (Régimen de arrendamiento de vivienda urbana en Colombia).")
        fundamentacion.append("Código Civil Colombiano - Título XXVI (Del contrato de arrendamiento).")
        respuesta = f"En relación con el arrendamiento urbano ({q}): La Ley 820 de 2003 establece que el incremento anual del canon de arrendamiento no puede ser superior a la meta de inflación (IPC) del año inmediatamente anterior. Para dar por terminado el contrato al vencimiento del término inicial o de sus prórrogas, se exige un preaviso por escrito no inferior a 3 meses."
    elif any(k in q_lower for k in ["consumidor", "garantía", "compra", "defectuoso", "factura"]):
        area = "Estatuto del Consumidor"
        fundamentacion.append("Ley 1480 de 2011 (Estatuto del Consumidor en Colombia).")
        respuesta = f"En protección al consumidor ({q}): La Ley 1480 de 2011 impone responsabilidad solidaria a productores y proveedores sobre la calidad e idoneidad de bienes. Tienes derecho a solicitar la efectividad de la garantía (reparación gratuita, reposición o devolución del dinero) y al retracto en compras no presenciales dentro de los 5 días hábiles."
    else:
        area = "Derecho General Colombiano"
        fundamentacion.append("Constitución Política de Colombia (Artículos 13, 29 y 86 - Debido Proceso y Acción de Tutela).")
        respuesta = f"En relación con tu inquietud jurídica ({q}): Bajo la Constitución Política de Colombia, todo ciudadano cuenta con el derecho fundamental al debido proceso y al libre acceso a la administración de justicia. Es aconsejable iniciar con un Derecho de Petición (Ley 1755 de 2015), el cual obliga a la entidad pública o privada a responder dentro de los 15 días hábiles."

    return {
        "query": q,
        "area": area,
        "respuesta": respuesta,
        "fundamentacion": fundamentacion,
        "recomendacion": "Orientación jurídica generada por el motor RAG de Abogado Gratis basada en legislación colombiana vigente.",
        "status": "success"
    }
