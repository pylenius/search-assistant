namespace SearchAssistant.Api.Common;

public static class ColorPalette
{
    // Distinct, high-contrast hues that read well on OpenStreetMap base layer.
    private static readonly string[] Colors =
    [
        "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6",
        "#3b82f6", "#6366f1", "#a855f7", "#ec4899", "#0ea5e9",
        "#84cc16", "#f43f5e",
    ];

    public static string PickForIndex(int participantCount) => Colors[participantCount % Colors.Length];
}
