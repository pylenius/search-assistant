using System.Security.Cryptography;

namespace SearchAssistant.Api.Common;

public static class SlugGenerator
{
    // Lowercase alphanumerics, no easily-confused glyphs (0/o/1/l).
    private const string Alphabet = "23456789abcdefghjkmnpqrstuvwxyz";
    private const int Length = 8;

    public static string Generate()
    {
        Span<byte> bytes = stackalloc byte[Length];
        RandomNumberGenerator.Fill(bytes);
        Span<char> chars = stackalloc char[Length];
        for (var i = 0; i < Length; i++)
        {
            chars[i] = Alphabet[bytes[i] % Alphabet.Length];
        }
        return new string(chars);
    }
}
