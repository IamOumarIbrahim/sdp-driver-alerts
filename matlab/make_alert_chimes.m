%% make_alert_chimes.m
% Generates the three acoustic alert stages for the driver monitoring system.
%
% Design rules (Chapter 5, Acoustic Alerts):
%   * Urgency rises by shortening the gap between pulses, not by raising
%     the volume. All three stages share the same peak level.
%   * Stage 1: one soft chime.
%   * Stage 2: three chimes.
%   * Stage 3: six fast chimes (the voice message and wheel vibration follow).
%   * Tones sit at 587-880 Hz (D5 to A5): warm rather than piercing, and
%     still above most road and engine noise, which lies below ~500 Hz.
%   * Every chime fades in over 35-55 ms and fades out over 150-200 ms, so
%     there are no clicks and nothing sounds like a harsh buzzer.
%   * Overtones are kept very weak and a low-pass filter (734 Hz, 12 dB per
%     octave) damps the high end, so the chimes sound round and soft.
%   * Notes come from the D major chord, so a sequence sounds like a short,
%     friendly melody instead of a repeated alarm.
%
% Output: 44.1 kHz, 16-bit mono WAV files in ../audio/
% Runs in MATLAB and in GNU Octave.

function make_alert_chimes()

fs      = 44100;              % sample rate (Hz)
peakdB  = -3;                 % common peak level for all stages (dBFS)
outDir  = fullfile(fileparts(mfilename('fullpath')), '..', 'audio');
if ~exist(outDir, 'dir'), mkdir(outDir); end

D5 = 587.33; Fs5 = 739.99; A5 = 880;
lpHz = 734;                   % low-pass cutoff that damps the high end (Hz)

% ---- Stage 1: one soft, warm chime -----------------------------------------
% Darker timbre (weak overtones) and a long gentle decay: a nudge, not an alarm.
soft  = struct('partials', [1 2 3], 'amps', [1 0.055 0.011], ...
               'taus', [0.35 0.15 0.08], 'len', 1.0, 'attack', 0.055, 'release', 0.20);
s1 = damp(sequence(fs, D5, 0, soft, 1.2), fs, lpHz);

% ---- Stage 2: three chimes, rising arpeggio --------------------------------
% D5 -> F#5 -> A5 every 0.40 s. Rising pitch asks for attention politely.
mid   = struct('partials', [1 2 3], 'amps', [1 0.0825 0.022], ...
               'taus', [0.25 0.12 0.07], 'len', 0.7, 'attack', 0.045, 'release', 0.17);
s2 = damp(sequence(fs, [D5 Fs5 A5], 0.40 * (0:2), mid, 1.6), fs, lpHz);

% ---- Stage 3: six fast chimes ----------------------------------------------
% The same arpeggio twice, every 0.16 s. Shorter decays keep the fast
% pulses clearly separate; urgency comes from the pace, not from sharpness.
fast  = struct('partials', [1 2 3], 'amps', [1 0.11 0.033], ...
               'taus', [0.14 0.07 0.05], 'len', 0.40, 'attack', 0.035, 'release', 0.15);
s3 = damp(sequence(fs, [D5 Fs5 A5 D5 Fs5 A5], 0.16 * (0:5), fast, 1.4), fs, lpHz);

% ---- Normalise to the same peak and save -----------------------------------
g = 10^(peakdB/20);
audiowrite(fullfile(outDir, 'stage1.wav'), g * s1 / max(abs(s1)), fs, 'BitsPerSample', 16);
audiowrite(fullfile(outDir, 'stage2.wav'), g * s2 / max(abs(s2)), fs, 'BitsPerSample', 16);
audiowrite(fullfile(outDir, 'stage3.wav'), g * s3 / max(abs(s3)), fs, 'BitsPerSample', 16);
fprintf('Wrote stage1.wav, stage2.wav and stage3.wav to %s\n', outDir);
end

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
    att = round(tb.attack * fs);                    % raised-cosine fade-in
    c(1:att) = c(1:att) .* (0.5 - 0.5*cos(pi*(0:att-1)'/att));
    rel = round(tb.release * fs);                   % raised-cosine fade-out
    c(end-rel+1:end) = c(end-rel+1:end) .* (0.5 + 0.5*cos(pi*(0:rel-1)'/rel));
end

function y = damp(x, fs, fc)
% Gentle damping: two passes of a one-pole low-pass filter (12 dB/octave).
    a = exp(-2*pi*fc/fs);
    y = filter(1 - a, [1 -a], filter(1 - a, [1 -a], x));
end
