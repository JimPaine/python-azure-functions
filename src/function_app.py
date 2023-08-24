import azure.functions as func
from math_functions import math_bp

app = func.FunctionApp()

app.register_functions(math_bp)