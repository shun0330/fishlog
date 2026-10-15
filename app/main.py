from fastapi import FastAPI

app = FastAPI(title="釣果記録API")

@app.get("/")
def root():
    return {"message": "釣果記録アプリ"}

@app.get("/health")
def health():
    return {"status": "ok"}
