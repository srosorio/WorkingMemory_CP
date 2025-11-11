function send_trigger(mode, P, code, pulseMs)
% -------------------------------------------------------------------------
% Alavie - Sternberg WM task
%
% Brain Products TriggerBox / TriggerBox Plus sender via PTB IOPort
%
% USAGE
%   send_trigger('init',  P)
%   send_trigger('send',  P, code, pulseMs)                                % code: 0..255; pulseMs defaults to P.trigger.pulseMs
%   send_trigger('set',   P, byte)                                         % force exact output byte
%   send_trigger('close', P)
%
% NOTES
%   - Uses a persistent struct TB so that the serial port is opened once
%     and reused on every call.
%   - Enforces a minimum gap between writes (USB safety)
%   - Supports mock mode via P.mock.triggerbox
%   - Designed for 8-bit triggers (0–255) - Brain product friendly :)
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
            % ---- read serial params from P (with safe fallbacks) ----
            port = P.trigger.comPort;
            if isfield(P,'trigger') && isfield(P.trigger,'serial') && isfield(P.trigger.serial,'baud')
                baud = P.trigger.serial.baud;
            else
                baud = 2000000;                                            % FIX: match working example
            end

            idleLevel  = uint8(getfield_def(P.trigger,'idleLevel',0));
            resetLevel = uint8(getfield_def(P.trigger,'resetLevel',255));
            minGap     = getfield_def(P.trigger,'minGapSec',0.010);        % FIX: 10 ms for USB safety

            % build persistent struct
            TB = struct( ...
                'fh',        [], ...
                'isOpen',    false, ...
                'mock',      false, ...
                'idle',      idleLevel, ...
                'reset',     resetLevel, ...
                'minGap',    minGap, ...
                'lastWriteT',0);

            % ---- mock mode (no hardware) ----
            if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                TB.mock   = true;
                TB.isOpen = true;
                fprintf('[MOCK TriggerBox] init OK (no hardware).\n');
                return;
            end

            % ---- open real serial port via PTB IOPort ----
            % FIX: DTR=0 RTS=0, no flow control, small timeouts, blocking writes later
            opts = sprintf([ ...
                'BaudRate=%d Parity=None DataBits=8 StopBits=1 ', ...
                'DTR=0 RTS=0 ReceiveTimeout=0.01 SendTimeout=0.01 ', ...
                'FlowControl=None'], baud);

            try
                [fh, errmsg] = IOPort('OpenSerialPort', port, opts);
                if ~isempty(errmsg), error('%s', errmsg); end

                TB.fh     = fh;
                TB.isOpen = true;

                % drive known idle and flush
                n = IOPort('Write', TB.fh, TB.idle, 1);  % FIX: blocking=1
                if n ~= 1
                    warning('Init write returned %d bytes.', n);
                end
                IOPort('Flush', TB.fh);

                fprintf('[TriggerBox] Opened %s @%d baud. Idle=%d (DTR/RTS off).\n', ...
                    port, baud, TB.idle);

            catch ME
                TB = [];
                error('[TriggerBox] Failed to open %s: %s', port, ME.message);
            end

        % =================================================================
        case 'send'
        % =================================================================
            % sanity checks
            if isempty(TB) || ~TB.isOpen
                warning('[TriggerBox] Not initialized. Call send_trigger(''init'',P) first.');
                return;
            end

            % mock send
            if TB.mock
                fprintf('[MOCK Trigger] code=%d pulseMs=%d @%.6f\n', code, pulseMs, GetSecs());
                return;
            end

            % guard time between writes
            nowT = GetSecs();
            dt   = nowT - TB.lastWriteT;
            if dt < TB.minGap
                WaitSecs(TB.minGap - dt);
            end

            % write trigger byte
            byte = uint8(bitand(code,255));
            n1   = IOPort('Write', TB.fh, byte, 1);  % FIX: blocking=1 (immediate edge)
            if n1 ~= 1
                warning('Trigger write returned %d bytes.', n1);
            end

            % hold pulse for requested ms
            if pulseMs > 0
                WaitSecs(pulseMs / 1000);
            end

            % return to idle level
            n2 = IOPort('Write', TB.fh, TB.idle, 1);  % FIX: blocking=1
            if n2 ~= 1
                warning('Idle write returned %d bytes.', n2);
            end

            TB.lastWriteT = GetSecs();

        % =================================================================
        case 'set'
        % =================================================================
            % set exact byte on output (no pulse)
            if isempty(TB) || ~TB.isOpen
                warning('[TriggerBox] Not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK Trigger SET] byte=%d @%.6f\n', code, GetSecs());
                return;
            end

            n = IOPort('Write', TB.fh, uint8(bitand(code,255)), 1);  % FIX: blocking=1
            if n ~= 1
                warning('Set write returned %d bytes.', n);
            end

            TB.lastWriteT = GetSecs();

        % =================================================================
        case 'close'
        % =================================================================
            % close port and drive reset level
            if ~isempty(TB) && TB.isOpen && ~TB.mock
                try
                    IOPort('Write', TB.fh, TB.reset, 1);  % FIX: blocking=1
                    WaitSecs(0.01);
                    IOPort('Close', TB.fh);
                catch
                    % ignore errors on close
                end
            end
            TB = [];
            fprintf('[TriggerBox] closed.\n');

        % =================================================================
        otherwise
            error('send_trigger: unknown mode "%s"', mode);
    end

else
    % test profile: don't touch hardware
    fprintf('[TEST - no Trigger] .\n');
end

end

% -------------------------------------------------------------------------
% helper: getfield_def
% return S.f if it exists, otherwise default d
% -------------------------------------------------------------------------
function v = getfield_def(S, f, d)
if isstruct(S) && isfield(S,f) && ~isempty(S.(f))
    v = S.(f);
else
    v = d;
end
end
