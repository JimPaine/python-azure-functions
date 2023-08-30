import json
import logging
import azure.functions as func

math_bp = func.Blueprint()

@math_bp.function_name(name="Add")
@math_bp.event_hub_message_trigger(arg_name="hub",
                               event_hub_name="demo",
                               connection="EventHubConnection")
def add_function(hub: func.EventHubEvent):
    o = json.loads(hub.get_body().decode('utf-8'))
    z = add(o["x"], o["y"])
    logging.info('%s + %s = %s', o["x"], o["y"], z)

def add(x: int, y: int) -> int:
    return x + y