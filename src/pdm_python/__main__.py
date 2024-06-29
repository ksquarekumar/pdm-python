import uvicorn


if __name__ == "__main__":
    import os

    uvicorn.run(
        "pdm_python.app:app",
        host="0.0.0.0",  # noqa: S104
        port=int(os.getenv("PORT", "8080")),
        reload=True,
    )
