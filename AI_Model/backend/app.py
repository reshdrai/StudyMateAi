from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
from backend.pipeline import analyze_text, analyze_image

app = FastAPI()


class NotesRequest(BaseModel):
    text: str


@app.post("/analyze_notes")
def analyze_notes(req: NotesRequest):
    return analyze_text(req.text)


@app.post("/analyze_notes_image")
async def analyze_notes_image(file: UploadFile = File(...)):
    image_bytes = await file.read()
    return analyze_image(image_bytes)