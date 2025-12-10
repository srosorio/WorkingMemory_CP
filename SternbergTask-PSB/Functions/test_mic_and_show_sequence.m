function threshold = test_mic_and_show_sequence()
%% Combined microphone test + digit-presentation test
% Fully integrated with event_logger
% Produces a CSV file automatically via event_logger
%
% Requires:
%   make_params
%   make_event_codes
%   event_logger
%
% Written 2025 — matches Sternberg task conventions

close all;

try
    %% --------------------------------------------------------------------
    %  PARAMETERS & SETUP
    % ---------------------------------------------------------------------
    P = make_params('test','OFFmed_OFFstim','S01');
    C = make_event_codes();   % same format as the main task
    
    % Audio configuration
    fs        = 16000;
    nChannels = 1;
    bits      = 16;

    noiseSecs  = 3;
    speechSecs = 5;
    noiseMultiplier = 5;

    % Behavioral save directory and logger initialization
    L = event_logger('init', P, C, 'DigitCount');

    %% --------------------------------------------------------------------
    %  OPEN SCREEN
    % ---------------------------------------------------------------------
    Screen('Preference','VisualDebugLevel', 0);
    Screen('Preference','SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', max(Screen('Screens')), 0);
    Screen('TextSize', win, P.screen.textSize);
    if isfield(P.screen,'fontName')
        Screen('TextFont', win, P.screen.fontName);
    end
    textColor = P.screen.textColor; 

    %% Record screen refresh info into logger
    ifi = Screen('GetFlipInterval', win);
    L.ifi        = ifi;
    L.refresh_hz = 1/ifi;
    L.screen_index = P.screen.whichScreen;

    %% --------------------------------------------------------------------
    %  BLOCK/TRIAL COUNTERS (single block with 1 "trial")
    % ---------------------------------------------------------------------
    L.block = 1;
    L.trial = 1;

    %% --------------------------------------------------------------------
    %  MIC TEST — STEP 1: Ambient Noise
    % ---------------------------------------------------------------------
    DrawFormattedText(win, sprintf('Step 1:\n\nStay silent for %d seconds...', noiseSecs), ...
        'center','center', textColor);
    t_on = Screen('Flip', win);

    WaitSecs(1);

    recNoise = audiorecorder(fs, bits, nChannels);
    recordblocking(recNoise, noiseSecs);
    noiseData = getaudiodata(recNoise);
    noiseRMS = rms(noiseData);
    threshold = noiseMultiplier * noiseRMS;


    %% --------------------------------------------------------------------
    %  MIC TEST — STEP 2: Speech Recording
    % ---------------------------------------------------------------------
    DrawFormattedText(win, sprintf('Step 2:\n\nSay numbers out loud (%d seconds)...', speechSecs), ...
        'center','center', textColor);
    t_on = Screen('Flip', win);

    WaitSecs(0.5);
    beep;
    WaitSecs(0.5);

    recSpeech = audiorecorder(fs, bits, nChannels);
    recordblocking(recSpeech, speechSecs);
    speechData = getaudiodata(recSpeech);
    %% --------------------------------------------------------------------
    %  MIC TEST — STEP 3: Playback
    % ---------------------------------------------------------------------
    DrawFormattedText(win, 'Playback...', 'center','center', textColor);
    t_on = Screen('Flip', win);
    sound(speechData, fs);
    WaitSecs(speechSecs + 0.5);

    %% --------------------------------------------------------------------
    %  SAVE NOISE + SPEECH FIGURE
    % ---------------------------------------------------------------------
    tNoise  = (1:length(noiseData))/fs;
    tSpeech = (1:length(speechData))/fs;

    fig = figure('Visible','off','Color','w');
    subplot(2,1,1); plot(tNoise, noiseData); hold on;
    yline(threshold,'r--','Threshold');
    xlabel('Time (s)'); ylabel('Amp'); title('Noise');

    subplot(2,1,2); plot(tSpeech, speechData); hold on;
    yline(threshold,'r--','Threshold');
    xlabel('Time (s)'); ylabel('Amp'); title('Speech');

    outFig = fullfile(P.audio.saveDir, 'NoiseSpeechTest.png');
    saveas(fig, outFig);
    close(fig);
    %% --------------------------------------------------------------------
    %  DIGIT PRESENTATION TEST
    % ---------------------------------------------------------------------
    L.phase = 'digit_task';

    % Generate 10 random digits
    seq = randi([0 9], [1 10]);

    % Initial fixation
    DrawFormattedText(win, '+', 'center','center', textColor);
    t_on = Screen('Flip', win);
    event_logger('add', L, 'digit_fix_start', C.TRIAL_START, t_on);
    WaitSecs(0.7);

    % --- Loop over digits ---
    for k = 1:10
        % Fixation BEFORE digit
        DrawFormattedText(win, '+', 'center','center', textColor);
        t_on = Screen('Flip', win);
        event_logger('add', L, 'inter_digit_fix', C.FIX1_ON, t_on);

        WaitSecs(0.5);

        % Present digit
        DrawFormattedText(win, num2str(seq(k)), 'center','center', textColor);
        t_on = Screen('Flip', win);
        event_logger('add', L, 'digit_on', C.DIGIT_ON, t_on, ...
            struct('value', seq(k)));

        WaitSecs(0.7);
    end

    %% --------------------------------------------------------------------
    %  END OF TASK
    % ---------------------------------------------------------------------
    L.phase = 'end';
    event_logger('add', L, 'task_end', C.SESSION_END, GetSecs());

    % Close logger (flush last row)
    event_logger('close', L);

    % Close screen
    sca;

catch ME
    sca;
    event_logger('close', L);
    rethrow(ME);
end

end
