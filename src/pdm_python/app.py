from litestar import Litestar, get


@get("/health", include_in_schema=False)
async def health() -> str:
    return "OK"


app = Litestar([health])
