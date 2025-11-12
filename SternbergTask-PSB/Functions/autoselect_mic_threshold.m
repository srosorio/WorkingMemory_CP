function threshold = autoselect_mic_threshold(P, plotFlag)
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

    %% --- Open PTB Screen ---
    Screen('Preference', 'SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', 0, 0);   % black screen
    Screen('TextSize', win, 32);
    Screen('TextFont', win, 'Arial');
    xCenter = rect(3)/2;
    yCenter = rect(4)/2;

    %% --- Step 1: Record ambient noise ---
    DrawFormattedText(win, sprintf('Step 1:\n\nStay silent for %d seconds...', noiseSecs), ...
        'center', 'center', [255 255 255]);
    Screen('Flip', win);

    recNoise = audiorecorder(fs, bits, nChannels);
    recordblocking(recNoise, noiseSecs);

    noiseData = getaudiodata(recNoise);
    noiseRMS = rms(noiseData);
    noiseMax = max(abs(noiseData));
    WaitSecs(2);

    %% --- Step 2: Compute threshold ---
    threshold = noiseMultiplier * noiseRMS;

    %% --- Step 3: Record speech sample ---
    DrawFormattedText(win, sprintf('Step 2:\n\nSpeak now after the beep for %d seconds...', speechSecs), ...
        'center', 'center', [255 255 255]);
    Screen('Flip', win);
    pause(0.5);

    recSpeech = audiorecorder(fs, bits, nChannels);
    recordblocking(recSpeech, speechSecs);

    speechData = getaudiodata(recSpeech);
    speechRMS  = rms(speechData);
    speechMax  = max(abs(speechData));
    Screen('Flip', win);
    WaitSecs(3);
    sca;
    %% --- Step 5: Plot if requested ---
    if plotFlag
        
        tNoise = (1:length(noiseData))/fs;
        tSpeech = (1:length(speechData))/fs;

        figure('Name','Noise and Speech Measurement','Color','w');
        subplot(2,1,1);
        plot(tNoise, noiseData); hold on;
        yline(threshold, 'r--', 'Threshold');
        title('Ambient Noise'); xlabel('Time (s)'); ylabel('Amplitude');

        subplot(2,1,2);
        plot(tSpeech, speechData); hold on;
        yline(threshold, 'r--', 'Threshold');
        title('Speech Sample'); xlabel('Time (s)'); ylabel('Amplitude');
    end

catch ME
    try sca; end
    disp('Error in autoselect_mic_threshold:');
    disp(ME.message);
    threshold = NaN;
end

end
