function R = get_tf_response_vocal(P, L, deadlineAbs, pahandle)
% -------------------------------------------------------------------------
% get_tf_response_vocal | Sternberg WM Task (vocal-response version)
%
% Waits for a vocal response until an absolute deadline.
% Uses PsychPortAudio to record from microphone and detect speech onset.
%
% INPUTS:
%   P            : struct with audio parameters (P.audio.*)
%   deadlineAbs  : absolute time (from GetSecs) at which to stop listening
%   pahandle     : initialized PsychPortAudio capture handle
%
% RETURNS struct R:
%   R.madeResponse : true/false
%   R.isTrue       : NaN (vocal mode, not scored online)
%   R.keyName      : '' (placeholder)
%   R.tPress       : time of speech onset (absolute)
%   R.rt           : NaN (caller computes onset - stimulusOnset)
%   R.audio        : full captured waveform (float)
%
% -------------------------------------------------------------------------

% Initialize output
R = struct( ...
    'madeResponse', false, ...
    'isTrue',       NaN, ...
    'keyName',      '', ...
    'tPress',       NaN, ...
    'rt',           NaN, ...
    'audio',        [] );

% -------------------- Audio parameters -----------------------------------
fs              = P.audio.fs;
chunkSec        = P.audio.chunkSec;
threshold       = P.audio.threshold;
silenceDuration = P.audio.silenceDuration;
postSilence     = P.audio.postSilence;

% -------------------- Start audio capture --------------------------------
PsychPortAudio('GetAudioData', pahandle, 0);  % clear any old data
PsychPortAudio('Start', pahandle, 0, 0, 1);

audioAll = [];
speechStarted  = false;
silenceCounter = 0;

% -------------------- Capture loop ---------------------------------------
while GetSecs() < deadlineAbs
    % Get small audio chunks
    [chunk, ~, ~, ~] = PsychPortAudio('GetAudioData', pahandle, 0);
    if isempty(chunk)
        WaitSecs(chunkSec);
        continue;
    end

    chunk = chunk(:);
    audioAll = [audioAll; chunk];

    % --- Detect speech onset ---
    if ~speechStarted && max(abs(chunk)) > threshold
        R.tPress = GetSecs();
        R.madeResponse = true;
        speechStarted = true;
    end

    % --- Silence tracking after onset ---
    if speechStarted
        if max(abs(chunk)) < threshold
            silenceCounter = silenceCounter + chunkSec;
        else
            silenceCounter = 0;
        end
        if silenceCounter >= silenceDuration
            break;
        end
    end
end

% -------------------- Stop capture ---------------------------------------
PsychPortAudio('Stop', pahandle);

% Pad post-silence zeros (for clean termination)
nPost = round(postSilence * fs);
audioAll = [audioAll; zeros(nPost,1)];

% save audio file
audioFileName = fullfile(P.audio.saveDir, sprintf('%s_Block0%s_Trial0%s_TrueFalse.wav', P.subjectID, num2str(L.block), num2str(L.trial)));

% Write waveform to WAV file
audiowrite(audioFileName, audioAll, fs);

R.isTrue = false;  % placeholder logical (so tf_label won’t error)

end
