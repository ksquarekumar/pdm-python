#!python3

if __name__ == "__main__":
    import logging
    import os

    import uvicorn

    uvicorn.run(
        "pdm_python.app:app",
        host="0.0.0.0",  # noqa: S104
        port=int(os.getenv("PORT", "8080")),
        reload=False,
        log_level=logging.getLevelNamesMapping()[os.environ.get("LOG_LEVEL", "INFO")],
    )
