function threshold = autoselect_mic_threshold(P, plot)
% -------------------------------------------------------------------------
% autoselect_micresponse_threshold  |  Sergio - Sternberg WM Task Helper
%
% Identifies noise floor and automatically selects a threshold for
% detecting vocal responses 
%
% USAGE
%   x = autoselect_micresponse_threshold(noiseSecs, speechSecs, noiseMultiplier)
%
% INPUT
%   P.audio    : Parameter structure containing audio settings
%   plot       : bool/int. Whether to plot signals and threshold
%
% OUTPUT
%   threshold   : threshold for detecting vocal responses
%
% -------------------------------------------------------------------------

try
    % --- Parameters ---
    fs              = P.audio.fs;                                          % Sampling rate (Hz)
    nChannels       = P.audio.nchannels;                                   % Mono input
    bits            = P.audio.bits;   
    noiseSecs       = P.audio.noiseSecs;
    speechSecs      = P.audio.speechSecs;
	noiseMultiplier = P.audio.noiseMultiplier ;
    
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
    pause(0.5);
    
    recSpeech = audiorecorder(fs, bits, nChannels);
    recordblocking(recSpeech, speechSecs);
    
    speechData = getaudiodata(recSpeech);
    speechRMS = rms(speechData);
    speechMax = max(abs(speechData)); 
    
    %% --- Step 5: Display info ---
    fprintf('\n--- Summary ---\n');
    fprintf('Noise RMS:  %.6f\n', noiseRMS);
    fprintf('Speech RMS: %.6f\n', speechRMS);
    fprintf('Speech Max: %.6f\n', speechMax);
    fprintf('Threshold : %.6f\n', threshold);
    
    %% --- Step 6: Plot results ---
    if plot==1
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
    end
catch ME
    disp('Error:');
    disp(ME.message);
end
end