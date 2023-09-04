import json
import logging
import os
import azure.functions as func

from azure.identity import ManagedIdentityCredential
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

client_id = os.getenv("EventHubConnection__clientId")
credential = ManagedIdentityCredential(client_id=client_id)

configure_azure_monitor(
    credential=credential,
)

tracer = trace.get_tracer(__name__)

math_bp = func.Blueprint()

@math_bp.function_name(name="Add")
@math_bp.event_hub_message_trigger(arg_name="hub",
                               event_hub_name="demo",
                               connection="EventHubConnection")
def add_function(hub: func.EventHubEvent):
    with tracer.start_as_current_span("add_function"):
        o = json.loads(hub.get_body().decode('utf-8'))
        z = add(o["x"], o["y"])
        logging.info('%s + %s = %s', o["x"], o["y"], z)

def add(x: int, y: int) -> int:
    return x + y