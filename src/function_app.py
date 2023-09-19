import azure.functions as func
from math_functions import math_bp

app = func.FunctionApp()

app.register_functions(math_bp)

@app.function_name(name="health")
@app.route(route="", auth_level=func.AuthLevel.ANONYMOUS)
def health_function(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Ping Test")