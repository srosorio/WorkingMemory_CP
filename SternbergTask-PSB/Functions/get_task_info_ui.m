function [P, confirmed] = get_task_info_ui(P)
% -------------------------------------------------------------------------
% Alavie - Sternberg WM task
%
% GET_TASK_INFO_UI - GUI to view and optionally modify experiment parameters
%
% Opens a simple UI to review and modify key fields in struct P
% (e.g., subjectID, condition, etc.) before running the experiment.
%
% Usage:
%   [P, confirmed] = get_task_info_ui(P)
%
% Notes:
%   - Supports nested fields (e.g., 'Text.taskCondition').
%   - Automatically displays P.runProfile if present.
%   - Enlarged window to prevent overlap of buttons and last fields.
% -------------------------------------------------------------------------

% -------- Editable fields --------
editableFields = { ...
    'subjectID', ...
    'sessionID', ...
    'condition', ...
    'runProfile', ...         % will populate from P if exists
    'eeg_system', ...
    'Text.taskCondition', ...
    'nBlocks', ...
    'nTrials', ...
    'numDigits' ...
    };

% -------- Figure setup --------
figW = 500;
figH = 520;  % larger to fit more comfortably
fig = figure('Name','Experiment Setup',...
    'MenuBar','none','ToolBar','none','NumberTitle','off',...
    'Position',[600 300 figW figH],...
    'Resize','off','Color',[0.95 0.95 0.95]);

% -------- Header --------
uicontrol(fig,'Style','text',...
    'String','🧠  Experiment Parameters Review',...
    'FontSize',13,'FontWeight','bold',...
    'Position',[20 figH-50 figW-40 30],...
    'BackgroundColor',[0.95 0.95 0.95],...
    'HorizontalAlignment','center');

% -------- Field positioning --------
n = numel(editableFields);
handles = struct();

labelX = 30; editX = 210;
labelW = 160; editW = 240;
startY = figH - 90;          % leave space below header
rowH = 30;                   % height of one row
gap = 10;                    % spacing between rows

% -------- Loop through fields --------
for i = 1:n
    field = editableFields{i};
    parts = strsplit(field,'.');

    % Get value (support nested fields)
    try
        val = getfield(P, parts{:});
    catch
        val = '';
    end

    % Compute Y position (top-down)
    yPos = startY - (i-1)*(rowH+gap);

    % Label
    uicontrol(fig,'Style','text',...
        'String',sprintf('%s:', field),...
        'Position',[labelX yPos labelW 22],...
        'HorizontalAlignment','right',...
        'BackgroundColor',[0.95 0.95 0.95]);

    % Safe handle name (no dots)
    safeFieldName = strrep(field,'.','_');

    % Special handling: runProfile dropdown
    if strcmpi(field,'runProfile')
        validProfiles = {'eeg','test','eyetracker','both'};
        valIdx = find(strcmpi(validProfiles, string(val)), 1);
        if isempty(valIdx), valIdx = 1; end
        handles.(safeFieldName) = uicontrol(fig,'Style','popupmenu',...
            'String',validProfiles,...
            'Value',valIdx,...
            'Position',[editX yPos editW 25],...
            'BackgroundColor','white');
    elseif strcmpi(field,'eeg_system')
        validProfiles = {'none','biosemi','brainproducts'};
        valIdx = 1;
        handles.(safeFieldName) = uicontrol(fig,'Style','popupmenu',...
            'String',validProfiles,...
            'Value',valIdx,...
            'Position',[editX yPos editW 25],...
            'BackgroundColor','white');
    else
        % Normal text input
        handles.(safeFieldName) = uicontrol(fig,'Style','edit',...
            'String',num2str(val),...
            'Position',[editX yPos editW 25],...
            'BackgroundColor','white');
    end
end

% -------- Buttons --------
btnY = 40;
uicontrol(fig,'Style','pushbutton',...
    'String','✅ Confirm','FontWeight','bold',...
    'Position',[100 btnY 130 45],...
    'Callback',@confirmCallback);

uicontrol(fig,'Style','pushbutton',...
    'String','❌ Cancel','FontWeight','bold',...
    'Position',[270 btnY 130 45],...
    'Callback',@cancelCallback);

% -------- Wait --------
confirmed = false;
uiwait(fig);

% -------- Confirm callback --------
    function confirmCallback(~,~)
        for j = 1:n
            fld = editableFields{j};
            safeFld = strrep(fld,'.','_');
            parts = strsplit(fld,'.');

            % Extract value (handle dropdown vs edit)
            if strcmpi(fld,'runProfile')
                validProfiles = handles.(safeFld).String;
                idx = handles.(safeFld).Value;
                val = string(validProfiles{idx});
            else
                txt = handles.(safeFld).String;
                val = try_num(txt);
            end

            % Assign back to struct
            switch numel(parts)
                case 1
                    P.(parts{1}) = val;
                case 2
                    P.(parts{1}).(parts{2}) = val;
            end
        end
        confirmed = true;
        uiresume(fig);
        delete(fig);
    end

% -------- Cancel callback --------
    function cancelCallback(~,~)
        confirmed = false;
        uiresume(fig);
        delete(fig);
    end
end

% -------- Helper: numeric conversion --------
function val = try_num(txt)
num = str2double(txt);
if ~isnan(num)
    val = num;
else
    val = strtrim(txt);
end
end
