import logging
import azure.functions as func

app = func.FunctionApp()

@app.function_name(name="Demo")
@app.event_hub_message_trigger(arg_name="hub",
                               event_hub_name="demo",
                               connection="EVENT_HUB_CONNECTION_STRING")
def test_function(hub: func.EventHubEvent):
    logging.info('Python EventHub trigger processed an event: %s',
                hub.get_body().decode('utf-8'))