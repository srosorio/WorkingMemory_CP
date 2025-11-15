function threshold = autoselect_mic_threshold(L, S, C, P)
% -------------------------------------------------------------------------
% autoselect_micresponse_threshold  |  PTB display version
%
% Identifies noise floor and automatically selects a threshold for
% detecting vocal responses, with PTB text screens for user instructions
%
% INPUT
%   P.audio       : Parameter structure containing audio settings
%   plotFlag      : bool/int. Whether to plot signals and threshold
%
% OUTPUT
%   threshold     : threshold for detecting vocal responses
% -------------------------------------------------------------------------

try
    %% --- Parameters ---
    fs              = P.audio.fs;                                          
    nChannels       = P.audio.nchannels;                                   
    bits            = P.audio.bits;   
    noiseSecs       = P.audio.noiseSecs;
    speechSecs      = P.audio.speechSecs;
    noiseMultiplier = P.audio.noiseMultiplier;

    %% --- Step 1: Record ambient noise ---
    % Show mic test instructions
    [~, L] = markEvent(P, L, S, C.TEST_NOISEFLOOR, 'TEST_NOISEFLOOR', struct(), ...
        @(w) DrawFormattedText(w, 'Step 1:\n\nStay silent for 3 seconds...', 'center', 'center', P.screen.textColor));
    
    event_logger('add', L, 'TEST_NOISEFLOOR', C.TEST_NOISEFLOOR, GetSecs(), 0, struct());

    % mark event
    if ~P.mock.triggerbox
        send_trigger('send', P, C.TEST_NOISEFLOOR, P.trigger.pulseMs);
    end

    recNoise = audiorecorder(fs, bits, nChannels);
    recordblocking(recNoise, noiseSecs);

    noiseData = getaudiodata(recNoise);
    noiseRMS = rms(noiseData);
    noiseMax = max(abs(noiseData));
    WaitSecs(2);

    %% --- Step 2: Compute threshold ---
    threshold = noiseMultiplier * noiseRMS;

catch ME
    try sca; end
    disp('Error in autoselect_mic_threshold:');
    disp(ME.message);
    threshold = NaN;
end

end