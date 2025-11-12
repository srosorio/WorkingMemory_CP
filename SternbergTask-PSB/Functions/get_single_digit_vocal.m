function R = get_single_digit_vocal(deadlineAbs, P, pahandle)
% -------------------------------------------------------------------------
% get_single_digit_vocal | Sergio - Sternberg WM Task (vocal recall version)
%
% Waits (blocking) for a single vocal digit response until an absolute deadline.
% Uses a persistent PsychPortAudio handle for EEG-friendly recording.
%
% INPUTS
%   deadlineAbs : absolute GetSecs() time to stop listening
%   P           : parameter struct (requires P.audio.* fields)
%   pahandle    : initialized PsychPortAudio capture handle (persistent)
%
% RETURNS struct R:
%   R.madeResponse : true if vocal response detected before deadline
%   R.digit        : NaN (digit decoding left for post-processing)
%   R.keyName      : 'vocal'
%   R.tPress       : GetSecs timestamp of detected speech onset
%   R.quit         : true if ESC pressed during recording
%   R.audioData    : raw captured audio waveform
% -------------------------------------------------------------------------

%% 1) Default return
R = struct( ...
    'madeResponse', false, ...
    'digit',        NaN, ...
    'keyName',      '', ...
    'tPress',       NaN, ...
    'quit',         false, ...
    'audioData',    []);

%% 2) Audio parameters
fs              = P.audio.fs;
chunkSec        = P.audio.chunkSec;
threshold       = P.audio.threshold;
silenceDuration = P.audio.silenceDuration;
postSilence     = P.audio.postSilence;
maxSecs         = deadlineAbs - GetSecs();

%% 3) Start audio capture
PsychPortAudio('GetAudioData', pahandle, 0);  % clear buffer
PsychPortAudio('Start', pahandle, 0, 0, 1);

audioAll       = [];
speechStarted  = false;
silenceCounter = 0;

%% 4) Capture loop
while GetSecs() < deadlineAbs
    [chunk, ~, ~, ~] = PsychPortAudio('GetAudioData', pahandle, 0);
    if isempty(chunk)
        WaitSecs(chunkSec);
        continue;
    end

    chunk = chunk(:);
    audioAll = [audioAll; chunk]; %#ok<AGROW>

    % ESC key abort
    [down, ~, kc] = KbCheck(-1);
    if down && kc(KbName('ESCAPE'))
        R.quit = true;
        break;
    end

    % Speech onset detection
    if ~speechStarted && max(abs(chunk)) > threshold
        R.madeResponse = true;
        R.tPress = GetSecs;
        R.keyName = 'vocal';
        speechStarted = true;
    end

    % Silence tracking after speech onset
    if max(abs(chunk)) < threshold
        silenceCounter = silenceCounter + chunkSec;
    else
        silenceCounter = 0;
    end

    if speechStarted && silenceCounter >= silenceDuration
        break;
    end
end

%% 5) Stop capture and pad post-silence
PsychPortAudio('Stop', pahandle);
nPostSamples = round(postSilence * fs);
audioAll = [audioAll; zeros(nPostSamples,1)];

R.audioData = audioAll;

end
