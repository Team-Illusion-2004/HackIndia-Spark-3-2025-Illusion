from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId
import os
from dotenv import load_dotenv
import aiofiles
import requests
from datetime import datetime
import json

load_dotenv()

app = FastAPI()

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
client = AsyncIOMotorClient(MONGODB_URL)
db = client.deepfake_detection

# SingularityNET AI service configuration
SNET_API_KEY = os.getenv("SNET_API_KEY")
SNET_API_ENDPOINT = os.getenv("SNET_API_ENDPOINT")

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        # Save file locally
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        async with aiofiles.open(file_path, 'wb') as out_file:
            content = await file.read()
            await out_file.write(content)

        # Call SingularityNET AI service
        ai_result = await analyze_media(file_path)

        # Store result in MongoDB
        media_doc = {
            "filename": file.filename,
            "upload_date": datetime.utcnow(),
            "ai_prediction": ai_result,
            "file_path": file_path,
            "votes": {
                "real": 0,
                "fake": 0
            }
        }
        
        result = await db.media.insert_one(media_doc)
        
        return {
            "id": str(result.inserted_id),
            "ai_prediction": ai_result,
            "message": "File uploaded and analyzed successfully"
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def analyze_media(file_path: str):
    """
    Call SingularityNET AI service to analyze the media file
    """
    try:
        with open(file_path, 'rb') as f:
            files = {'file': f}
            headers = {'X-API-Key': SNET_API_KEY}
            
            response = requests.post(
                SNET_API_ENDPOINT,
                files=files,
                headers=headers
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                raise HTTPException(
                    status_code=response.status_code,
                    detail="AI service analysis failed"
                )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/media/{media_id}")
async def get_media(media_id: str):
    try:
        media = await db.media.find_one({"_id": ObjectId(media_id)})
        if media:
            media["_id"] = str(media["_id"])
            return media
        raise HTTPException(status_code=404, detail="Media not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/vote/{media_id}")
async def vote(media_id: str, vote_type: str):
    if vote_type not in ["real", "fake"]:
        raise HTTPException(status_code=400, detail="Invalid vote type")
    
    try:
        result = await db.media.update_one(
            {"_id": ObjectId(media_id)},
            {"$inc": {f"votes.{vote_type}": 1}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Media not found")
            
        return {"message": "Vote recorded successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/media")
async def list_media():
    try:
        cursor = db.media.find().sort("upload_date", -1)
        media_list = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            media_list.append(doc)
        return media_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) 
