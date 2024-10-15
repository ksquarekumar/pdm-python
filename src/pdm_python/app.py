from litestar import Litestar, get
from litestar.response import Redirect
from litestar.status_codes import HTTP_302_FOUND


@get("/health", include_in_schema=True)
async def health() -> str:
    return "OK"


@get("/ping", include_in_schema=True)
async def ping() -> str:
    return "pong"


@get(path="/", status_code=HTTP_302_FOUND, include_in_schema=False)
def redirect() -> Redirect:
    return Redirect(path="/schema")


app = Litestar([health, redirect])
