function send_trigger_biosemi(mode, P, code, pulseMs)
% -------------------------------------------------------------------------
% send_trigger_biosemi  |  Sternberg WM task
%
% Biosemi ActiveTwo trigger sender via parallel port (io64)
%
% USAGE:
%   send_trigger_biosemi('init',  P)
%   send_trigger_biosemi('send',  P, code, pulseMs)
%   send_trigger_biosemi('set',   P, byte)
%   send_trigger_biosemi('close', P)
%
% NOTES:
%   - For Biosemi ActiveTwo trigger input (8-bit TTL via parallel port)
%   - Uses Psychtoolbox I/O driver (io64)
%   - Pulses are held high for pulseMs milliseconds, then reset to 0
%   - Idle level = 0 (all lines low)
%   - Requires parallel port driver (InpOutx64.dll) installed
%   - Compatible with existing 'P' parameter structure
% -------------------------------------------------------------------------

persistent TB IO_DRIVER_LOADED

if nargin < 4 || isempty(pulseMs)
    pulseMs = P.trigger.pulseMs;
end

if ~ismember(P.runProfile, 'test')

    switch lower(mode)

        %% =================================================================
        case 'init'
        %% =================================================================
            % Mock mode check first
            if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                TB = struct('mock', true, 'isOpen', true, 'lastWriteT', 0);
                fprintf('[MOCK Biosemi Trigger] init OK (no hardware)\n');
                return;
            end

            fprintf('[BIOSEMI] Initializing parallel port trigger interface...\n');

            % Load io64 driver only once
            if isempty(IO_DRIVER_LOADED)
                try
                    config_io;
                    IO_DRIVER_LOADED = true;
                catch
                    error('Could not initialize io64. Ensure Psychtoolbox I/O driver is installed.');
                end
            end

            % Determine parallel port address
            if isfield(P,'trigger') && isfield(P.trigger,'portAddress')
                address = P.trigger.portAddress;
            else
                address = hex2dec('378'); % default LPT1
            end

            % Build persistent struct
            TB = struct( ...
                'ioObj', io64, ...
                'address', address, ...
                'isOpen', true, ...
                'mock', false, ...
                'lastWriteT', 0);

            % Test write (set idle 0)
            try
                io64(TB.ioObj, TB.address, 0);
            catch ME
                error('Failed to write to LPT port @0x%x\nError: %s', TB.address, ME.message);
            end

            fprintf('[BIOSEMI] Parallel port ready @0x%x (idle=0)\n', TB.address);

        %% =================================================================
        case 'send'
        %% =================================================================
            if isempty(TB) || ~TB.isOpen
                warning('[BIOSEMI] Not initialized. Call send_trigger_biosemi(''init'',P) first.');
                return;
            end

            if TB.mock
                fprintf('[MOCK Trigger] code=%d pulseMs=%d @%.6f\n', code, pulseMs, GetSecs());
                return;
            end

            % Guard for minimum gap between triggers
            if isfield(P.trigger,'minGapSec')
                dt = GetSecs() - TB.lastWriteT;
                if dt < P.trigger.minGapSec
                    WaitSecs(P.trigger.minGapSec - dt);
                end
            end

            % Ensure 8-bit value
            byte = uint8(bitand(code, 255));

            % Send TTL pulse
            io64(TB.ioObj, TB.address, byte);
            WaitSecs(pulseMs / 1000);
            io64(TB.ioObj, TB.address, 0);

            TB.lastWriteT = GetSecs();

        %% =================================================================
        case 'set'
        %% =================================================================
            if isempty(TB) || ~TB.isOpen
                warning('[BIOSEMI] Not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK Trigger SET] byte=%d @%.6f\n', code, GetSecs());
                return;
            end

            io64(TB.ioObj, TB.address, uint8(bitand(code, 255)));
            TB.lastWriteT = GetSecs();

        %% =================================================================
        case 'close'
        %% =================================================================
            if ~isempty(TB) && TB.isOpen && ~TB.mock
                io64(TB.ioObj, TB.address, 0);  % ensure lines low
                fprintf('[BIOSEMI] Parallel port closed (reset to 0)\n');
            end
            TB = [];

        %% =================================================================
        otherwise
            error('send_trigger_biosemi: unknown mode "%s"', mode);
    end

else
    fprintf('[TEST MODE] No trigger sent.\n');
end

end