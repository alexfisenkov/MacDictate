using System.Buffers.Binary;

namespace MacDictate.Core;

// PCM16 mono metadata only. No audio samples are retained.
public sealed class PcmSignalMeter
{
    private long samples, audible;
    private double squares, peak;
    public double Level { get; private set; }
    public bool HasSignal => samples >= 8000 && audible >= 800 && peak >= .01 && Math.Sqrt(squares / Math.Max(1, samples)) >= .002;
    public void Append(ReadOnlySpan<byte> pcm)
    {
        double current = 0;
        for (int i = 0; i + 1 < pcm.Length; i += 2)
        {
            double value = Math.Abs((double)BinaryPrimitives.ReadInt16LittleEndian(pcm.Slice(i, 2))) / 32768;
            current = Math.Max(current, value); squares += value * value; samples++;
            if (value >= .005) audible++;
        }
        peak = Math.Max(peak, current); Level = current;
    }
}
