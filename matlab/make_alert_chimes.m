%% make_alert_chimes.m
% Generates the three acoustic alert stages for the driver monitoring system.
%
% Design rules (Chapter 5, Acoustic Alerts):
%   * Urgency rises by shortening the gap between pulses, not by raising
%     the volume. All three stages share the same peak level.
%   * Stage 1: one soft chime.
%   * Stage 2: three chimes.
%   * Stage 3: six fast chimes (the voice message and wheel vibration follow).
%   * Tones sit at 880-1760 Hz, above most road and engine noise, where the
%     ear is sensitive, but below the shrill range above 3 kHz.
%   * Every chime has a soft 8 ms attack and a natural bell-like decay, so
%     there are no clicks and nothing sounds like a harsh buzzer.
%   * Notes come from the A major chord, so a sequence sounds like a short,
%     friendly melody instead of a repeated alarm.
%
% Output: 44.1 kHz, 16-bit mono WAV files in ../audio/

fs      = 44100;              % sample rate (Hz)
peakdB  = -3;                 % common peak level for all stages (dBFS)
outDir  = fullfile(fileparts(mfilename('fullpath')), '..', 'audio');
if ~exist(outDir, 'dir'), mkdir(outDir); end

A5 = 880; Cs6 = 1108.73; E6 = 1318.51; A6 = 1760;

% ---- Stage 1: one soft, warm chime -----------------------------------------
% Darker timbre (weak overtones) and a long gentle decay: a nudge, not an alarm.
soft  = struct('partials', [1 2 3], 'amps', [1 0.18 0.05], ...
               'taus', [0.30 0.15 0.08], 'len', 0.9);
s1 = sequence(fs, A5, 0, soft, 1.2);

% ---- Stage 2: three chimes, rising arpeggio --------------------------------
% A5 -> C#6 -> E6 every 0.40 s. Rising pitch asks for attention politely.
mid   = struct('partials', [1 2 3 4.2], 'amps', [1 0.30 0.12 0.05], ...
               'taus', [0.22 0.12 0.07 0.04], 'len', 0.6);
s2 = sequence(fs, [A5 Cs6 E6], 0.40 * (0:2), mid, 1.6);

% ---- Stage 3: six fast chimes ----------------------------------------------
% The arpeggio twice, one step higher, every 0.16 s. Brighter overtones and
% shorter decays keep the fast pulses crisp and clearly separate.
bright = struct('partials', [1 2 3 4.2], 'amps', [1 0.45 0.22 0.10], ...
                'taus', [0.12 0.07 0.05 0.03], 'len', 0.35);
s3 = sequence(fs, [Cs6 E6 A6 Cs6 E6 A6], 0.16 * (0:5), bright, 1.4);

% ---- Normalise to the same peak and save -----------------------------------
g = 10^(peakdB/20);
audiowrite(fullfile(outDir, 'stage1.wav'), g * s1 / max(abs(s1)), fs, 'BitsPerSample', 16);
audiowrite(fullfile(outDir, 'stage2.wav'), g * s2 / max(abs(s2)), fs, 'BitsPerSample', 16);
audiowrite(fullfile(outDir, 'stage3.wav'), g * s3 / max(abs(s3)), fs, 'BitsPerSample', 16);
fprintf('Wrote stage1.wav, stage2.wav and stage3.wav to %s\n', outDir);

% ============================================================================
function y = sequence(fs, freqs, onsets, timbre, totalLen)
% Place one chime per frequency at the given onset times (s).
    y = zeros(round(totalLen * fs), 1);
    for k = 1:numel(freqs)
        c  = chime(fs, freqs(k), timbre);
        i0 = round(onsets(k) * fs) + 1;
        i1 = min(i0 + numel(c) - 1, numel(y));
        y(i0:i1) = y(i0:i1) + c(1:i1 - i0 + 1);
    end
end

function c = chime(fs, f0, tb)
% Bell-like chime: decaying partials, slight detune for warmth, soft attack.
    n = round(tb.len * fs);
    t = (0:n-1)' / fs;
    c = zeros(n, 1);
    for p = 1:numel(tb.partials)
        f = f0 * tb.partials(p);
        env = exp(-t / tb.taus(p));
        % two copies detuned by +/-1.2 Hz give a gentle shimmer
        c = c + tb.amps(p) * env .* 0.5 .* (sin(2*pi*(f - 1.2)*t) + sin(2*pi*(f + 1.2)*t));
    end
    att = round(0.008 * fs);                        % 8 ms raised-cosine attack
    c(1:att) = c(1:att) .* (0.5 - 0.5*cos(pi*(0:att-1)'/att));
    rel = round(0.030 * fs);                        % 30 ms fade at the tail
    c(end-rel+1:end) = c(end-rel+1:end) .* (0.5 + 0.5*cos(pi*(0:rel-1)'/rel));
end
