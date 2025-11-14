%% Measure microphone noise floor and record speech sample
close all;
clearvars;

try
    % --- Parameters ---
    fs = 16000;          % Sampling rate (Hz)
    nChannels = 1;       % Mono input
    bits = 16;           % Bit depth
    noiseSecs = 3;       % Duration of silence recording
    speechSecs = 5;      % Duration of speech recording
    noiseMultiplier = 5; % Multiplier for speech threshold heuristic

    %% --- Step 1: Record ambient noise ---
    fprintf('\n>>> Step 1: Measuring ambient noise floor (stay silent for %d s)...\n', noiseSecs);
    recNoise = audiorecorder(fs, bits, nChannels);
    recordblocking(recNoise, noiseSecs);

    noiseData = getaudiodata(recNoise);
    noiseRMS = rms(noiseData);
    noiseMax = max(abs(noiseData));

    fprintf('Noise RMS: %.6f | Noise max amplitude: %.6f\n', noiseRMS, noiseMax);

    %% --- Step 2: Compute suggested speech detection threshold ---
    threshold = noiseMultiplier * noiseRMS;
    fprintf('Suggested speech detection threshold (%.0fx noise RMS): %.6f\n', noiseMultiplier, threshold);

    %% --- Step 3: Record speech sample ---
    fprintf('\n>>> Step 2: Speak now after the beep (%d seconds)...\n', speechSecs);
    beep;
    pause(0.5);

    recSpeech = audiorecorder(fs, bits, nChannels);
    recordblocking(recSpeech, speechSecs);

    speechData = getaudiodata(recSpeech);
    speechRMS = rms(speechData);
    speechMax = max(abs(speechData));

    %% --- Step 4: Playback ---
    fprintf('Playback of captured speech...\n');
    sound(speechData, fs);

    %% --- Step 5: Display info ---
    fprintf('\n--- Summary ---\n');
    fprintf('Noise RMS:  %.6f\n', noiseRMS);
    fprintf('Speech RMS: %.6f\n', speechRMS);
    fprintf('Speech Max: %.6f\n', speechMax);
    fprintf('Threshold : %.6f\n', threshold);

    %% --- Step 6: Plot results ---
    tNoise = (1:length(noiseData))/fs;
    tSpeech = (1:length(speechData))/fs;

    figure('Name','Noise and Speech Measurement','Color','w');
    subplot(2,1,1);
    plot(tNoise, noiseData); hold on;
    yline(threshold, 'r--', 'Threshold');
    title('Ambient Noise'); xlabel('Time (s)'); ylabel('Amplitude');
    legend('Signal','Threshold');

    subplot(2,1,2);
    plot(tSpeech, speechData); hold on;
    yline(threshold, 'r--', 'Threshold');
    title('Speech Sample'); xlabel('Time (s)'); ylabel('Amplitude');
    legend('Signal','Threshold');

    fprintf('\nDone. Adjust "noiseMultiplier" if threshold is too sensitive.\n');

catch ME
    disp('Error:');
    disp(ME.message);
end
