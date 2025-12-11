function send_trigger_biosemi(mode, P, code, pulseMs)
% -------------------------------------------------------------------------
% Alavie - Sternberg WM task (BioSemi version)
%
% Sends TTL triggers via BioSemi USB/serial interface
%
% USAGE
%   send_trigger('init',  P)
%   send_trigger('send',  P, code, pulseMs)     % code: 0..255; pulseMs defaults to P.trigger.pulseMs
%   send_trigger('set',   P, byte)              % force exact output byte
%   send_trigger('close', P)
%
% NOTES
%   - Uses a persistent struct TB to keep serial port open
%   - Optional mock mode via P.mock.triggerbox
%   - Pulse width handled via WaitSecs; writes 0 after pulse if pulseMs > 0
% -------------------------------------------------------------------------

persistent TB

% default pulse width from params
if nargin < 4 || isempty(pulseMs)
    pulseMs = P.trigger.pulseMs;
end

% In 'test' runProfile we just print and do nothing.
if ~ismember(P.runProfile, 'test')

    switch lower(mode)

        % =================================================================
        case 'init'
            % =================================================================
            port = 'COM6'; %RP.trigger.comPort;                  % e.g., 'COM3' or '/dev/ttyUSB1'
            if isfield(P,'trigger') && isfield(P.trigger,'serial') && isfield(P.trigger.serial,'baudBS')
                baud = P.trigger.serial.baudBS;
            else
                baud = 2000000;                                            % FIX: match working example
            end

            TB = struct( ...
                'fh', [], ...
                'isOpen', false, ...
                'mock', false, ...
                'lastWriteT',0);

            % ---- mock mode ----
            if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                TB.mock   = true;
                TB.isOpen = true;
                fprintf('[MOCK BioSemi] init OK (no hardware).\n');
                return;
            end

            % ---- open serial port ----
            try
                TB.fh = serial(port, 'BaudRate', baud, 'DataBits', 8, ...
                    'StopBits', 1, 'Parity', 'none', 'FlowControl', 'none');
                fopen(TB.fh);
                TB.isOpen = true;
                fprintf('[BioSemi] Serial opened %s @%d baud\n', port, baud);
            catch ME
                TB = [];
                error('[BioSemi] Failed to open serial port %s: %s', port, ME.message);
            end

            % =================================================================
        case 'send'
            % =================================================================
            if isempty(TB) || ~TB.isOpen
                warning('[BioSemi] Not initialized. Call send_trigger(''init'',P) first.');
                return;
            end

            if TB.mock
                fprintf('[MOCK BioSemi] code=%d pulseMs=%d @%.6f\n', code, pulseMs, GetSecs());
                return;
            end

            % optional minimum gap (10 ms)
            nowT = GetSecs();
            dt   = nowT - TB.lastWriteT;
            if dt < 0.01
                WaitSecs(0.01 - dt);
            end

            % send trigger
            fwrite(TB.fh, uint8(bitand(code,255)));

            % hold pulse if requested
            if pulseMs > 0
                WaitSecs(pulseMs / 1000);
                fwrite(TB.fh, uint8(0));   % reset line to 0
            end

            TB.lastWriteT = GetSecs();

            % =================================================================
        case 'set'
            % =================================================================
            if isempty(TB) || ~TB.isOpen
                warning('[BioSemi] Not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK BioSemi SET] byte=%d @%.6f\n', code, GetSecs());
                return;
            end

            fwrite(TB.fh, uint8(bitand(code,255)));
            TB.lastWriteT = GetSecs();

            % =================================================================
        case 'close'
            % =================================================================
            if ~isempty(TB) && TB.isOpen && ~TB.mock
                try
                    fclose(TB.fh);
                    delete(TB.fh);
                catch
                    % ignore errors
                end
            end
            TB = [];
            fprintf('[BioSemi] Serial closed.\n');

            % =================================================================
        otherwise
            error('send_trigger: unknown mode "%s"', mode);
    end

end

end