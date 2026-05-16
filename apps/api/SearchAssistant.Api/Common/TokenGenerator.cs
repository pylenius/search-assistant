using System.Security.Cryptography;

namespace SearchAssistant.Api.Common;

public static class TokenGenerator
{
    public static string Generate(int byteLength = 24)
    {
        Span<byte> bytes = stackalloc byte[byteLength];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToHexStringLower(bytes);
    }
}
