namespace MacDictate.Core;

// A form-local failure must survive rendering the unchanged controller message.
public sealed class LocalErrorState
{
    private string controllerMessage = "", localError = "";
    public string Text => localError.Length > 0 ? localError : controllerMessage;
    public bool Visible => Text.Length > 0;
    public void ShowError(string text) => localError = text;
    public void Render(string message)
    {
        if (message != controllerMessage) localError = "";
        controllerMessage = message;
    }
}
