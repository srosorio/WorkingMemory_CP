function pahandle = initialize_ptb_sound(fs, nchannels, maxSecs)
% -------------------------------------------------------------------------
% initialize_ptb_sound  |  Sergio - Sternberg WM Task Helper
%
% Initializes PTB PsychPortAudio for registering vocal responses
%
% USAGE
%   x = initialize_ptb_sound(fs, nChannels, maxSecs)
%
% INPUT
%   fs          : int. Sampling rate for audio recording.
%   nchannels   : int. Number of audio channels (1 mono, 2 stereo)
%   maxSecs     : int. Max number of seconds to pre-fill buffer
%
% OUTPUT
%   pahandle    : a device handle for the initialized audio device
%
% -------------------------------------------------------------------------
try
    testHandle = PsychPortAudio('Open', [], 1);
    PsychPortAudio('Close', testHandle);
catch
    disp('Initializing Psychtoolbox sound engine...');
    InitializePsychSound(1);
end

pahandle = PsychPortAudio('Open', [], 2, 1, fs, nchannels, 0);
PsychPortAudio('GetAudioData', pahandle, maxSecs);  % pre-fill buffer
end