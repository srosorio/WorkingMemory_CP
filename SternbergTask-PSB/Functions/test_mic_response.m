function threshold = test_mic_response(P, C, L)
%% Measure microphone noise floor and record speech sample with PTB screens
% P: parameter structure containing P.screen.textSize and optionally P.screen.fontName
close all;

try
    % --- Parameters ---
    % P               = make_params('test','OFFmed_OFFstim','S01');
    fs              = 16000;          % Sampling rate (Hz)
    nChannels       = 1;       % Mono input
    bits            = 16;           % Bit depth
    noiseSecs       = 3;       % Duration of silence recording
    speechSecs      = 5;      % Duration of speech recording
    noiseMultiplier = 5; % Multiplier for speech threshold heuristic
    outputFigFile   = 'Noise_Speech_Measurement.png'; % File to save figure

    % --- Open PTB screen ---
    Screen('Preference', 'VisualDebugLevel', 0);
    Screen('Preference','SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', P.screen.whichScreen, 0); % black background
    
    % Set text size and font to match rest of experiment
    Screen('TextSize', win, P.screen.textSize);
    if isfield(P.screen,'fontName')
        Screen('TextFont', win, P.screen.fontName);
    end
    textColor = P.screen.textColor; % typically [255 255 255] or from P.screen
    
    %% --- Step 1: Record ambient noise ---
    event_logger('add', L, 'MIC_NOISEFLOOR', C.MIC_NOISEFLOOR, GetSecs(), 0, struct());
    if ~P.mock.triggerbox
        send_trigger_unified('send', P, C.MIC_NOISEFLOOR, P.trigger.pulseMs);
    end

    DrawFormattedText(win, sprintf('Step 1:\n\nStay silent for %d seconds...', noiseSecs), ...
        'center','center', textColor);
    Screen('Flip', win);
    WaitSecs(1);  % small pause before recording

    recNoise = audiorecorder(fs, bits, nChannels);
    recordblocking(recNoise, noiseSecs);

    noiseData = getaudiodata(recNoise);
    noiseRMS = rms(noiseData);
    noiseMax = max(abs(noiseData));

    %% --- Step 2: Compute threshold ---
    threshold = noiseMultiplier * noiseRMS;
    fprintf('\n\nRecommended threshold for vocal response detection %d seconds...', threshold);

    %% --- Step 3: Record speech sample ---
    event_logger('add', L, 'MIC_REC_SPEECH', C.MIC_REC_SPEECH, GetSecs(), 0, struct());
    if ~P.mock.triggerbox
        send_trigger_unified('send', P, C.MIC_REC_SPEECH, P.trigger.pulseMs);
    end

    DrawFormattedText(win, 'Step 2:\n\nCount from 1 to 3 out loud ...', ...
        'center','center', textColor);
    Screen('Flip', win);
    WaitSecs(0.5);
    pause(1);

    recSpeech = audiorecorder(fs, bits, nChannels);
    recordblocking(recSpeech, speechSecs);

    speechData = getaudiodata(recSpeech);
    % speechRMS = rms(speechData);
    % speechMax = max(abs(speechData));

    %% --- Step 4: Playback ---
    event_logger('add', L, 'MIC_SPEECH_OUT', C.MIC_SPEECH_OUT, GetSecs(), 0, struct());
    if ~P.mock.triggerbox
        send_trigger_unified('send', P, C.MIC_SPEECH_OUT, P.trigger.pulseMs);
    end

    DrawFormattedText(win, 'Playback of captured speech...', 'center','center', textColor);
    Screen('Flip', win);
    sound(speechData, fs);
    WaitSecs(speechSecs + 0.5);

    %% --- Step 5: Plot and save results ---
    tNoise = (1:length(noiseData))/fs;
    tSpeech = (1:length(speechData))/fs;

    fig = figure('Visible','off','Color','w'); % Do not show figure
    subplot(2,1,1);
    plot(tNoise, noiseData); hold on;
    yline(threshold, 'r--', 'Threshold');
    title('Ambient Noise'); xlabel('Time (s)'); ylabel('Amplitude'); legend('Signal','Threshold');

    subplot(2,1,2);
    plot(tSpeech, speechData); hold on;
    yline(threshold, 'r--', 'Threshold');
    title('Speech Sample'); xlabel('Time (s)'); ylabel('Amplitude'); legend('Signal','Threshold');

    saveas(fig, fullfile(P.audio.saveDir, outputFigFile));
    close(fig);

    

    % Close PTB window
    sca;

catch ME
    sca; % close PTB if error
    disp('Error:');
    disp(ME.message);
end

end
