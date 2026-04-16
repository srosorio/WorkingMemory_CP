function update_vocal_responses(participant_id, runProfile, condition, block)
%UPDATE_VOCAL_RESPONSES Update task CSV with vocal responses from Whisper
%
% This function reads the original CSV exported from the task and the JSON
% containing transcribed vocal responses, then updates the CSV with the
% actual responses (digits recalled and distractor responses).
%
% Now supports multiple CSV files (e.g., multiple blocks).

%% --------------------------
% --- User settings ---
%% --------------------------
mainDir = 'C:\Users\saosorio\Projects\WorkingMemory_CP\SternbergTask-PSB\output';

% CSV exported from task (pattern unchanged)
csv_path = fullfile(mainDir, runProfile, participant_id, condition, block, ...
    sprintf('%s_%s_wm_%s_events.csv', ...
    participant_id, block, condition));

csv_struct = dir(csv_path);

% ---- SAFETY CHECK ----
assert(~isempty(csv_struct), ...
    'No CSV file found matching pattern:\n%s', csv_path);

fprintf('Found %d CSV file(s) to update.\n', numel(csv_struct));

% JSON with transcribed vocal responses (shared)
json_file = fullfile(mainDir, runProfile, participant_id, condition, block, ...
    'AudioFiles', 'transcriptions_clean.json');

%% --------------------------
% --- Load JSON transcriptions once ---
%% --------------------------
fid = fopen(json_file,'r');
if fid == -1
    error('Cannot open JSON file: %s', json_file);
end
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
data_json = jsondecode(str);

%% ==========================================================
% === LOOP OVER ALL MATCHING CSV FILES ======================
%% ==========================================================
for f = 1:numel(csv_struct)

    csv_file = fullfile(csv_struct(f).folder, csv_struct(f).name);
    output_csv = replace(csv_file, '.csv', '_updated.csv');

    fprintf('\n🔄 Updating file: %s\n', csv_struct(f).name);

    %% --------------------------
    % --- Load CSV table ---
    %% --------------------------
    opts = detectImportOptions(csv_file,'Delimiter',',');
    opts = setvartype(opts,'char');  % Read all as char
    T = readtable(csv_file, opts);

    %% --------------------------
    % --- Update reading digit ---
    %% --------------------------
    for i = 1:height(T)
        row = T(i,:);
        if strcmp(row.phase, 'reading') && contains(row.event_name, 'PROBE_COUNT_OK')
            tokens = regexp(row.event_name, 'PROBE_COUNT_OK_(\d+)', 'tokens');
            if ~isempty(tokens)
                slot_num = str2double(tokens{1}{1});

                audio_file = sprintf('%s_%s_trial%02d_digit%02d.wav', ...
                    row.subject{1}, block, ...
                    str2double(row.trial{1}), slot_num);

                audio_field = strrep(audio_file, '.', '_');

                if isfield(data_json, audio_field)
                    entered = data_json.(audio_field);

                    T.entered_value{i} = num2str(entered);

                    row_json = jsondecode(T.json{i});
                    row_json.entered = entered;
                    T.json{i} = jsonencode(row_json);

                    isCorrect = strcmp(T.value_shown{i-1}, T.entered_value{i});
                    T.correct{i} = num2str(isCorrect);
                end
            end
        end
    end

    %% --------------------------
    % --- Update probe digit recall ---
    %% --------------------------
    for i = 1:height(T)
        row = T(i,:);
        if strcmp(row.phase, 'probe') && contains(row.event_name, 'PROBE_DIGIT_OK')
            tokens = regexp(row.event_name, 'PROBE_DIGIT_OK_(\d+)', 'tokens');
            if ~isempty(tokens)
                slot_num = str2double(tokens{1}{1});

                audio_file = sprintf('%s_%s_trial%02d_digit%02d.wav', ...
                    row.subject{1}, block, ...
                    str2double(row.trial{1}), slot_num);

                audio_field = strrep(audio_file, '.', '_');

                if isfield(data_json, audio_field)
                    entered = data_json.(audio_field);

                    T.entered_value{i} = num2str(entered);

                    row_json = jsondecode(T.json{i});
                    row_json.entered = entered;
                    T.json{i} = jsonencode(row_json);

                    isCorrect = strcmp( ...
                        T.value_shown{i-(26+slot_num)}, ...
                        T.entered_value{i});

                    T.correct{i} = num2str(isCorrect);
                end
            end
        end
    end

%%% --------------------------
% --- Update distractor responses ---
%% --------------------------
for i = 1:height(T)
    row = T(i,:);
    if strcmp(row.phase, 'distractor') && strcmp(row.event_name, 'DISTRACTOR_ANS')

        % Build audio filename and JSON field key
        audio_file = sprintf('%s_%s_trial%02d_truefalse.wav', ...
            row.subject{1}, block, ...
            str2double(row.trial{1}));

        audio_field = strrep(audio_file, '.', '_');

        if isfield(data_json, audio_field)
            entered = data_json.(audio_field);  % e.g. 'true' or 'false' from Whisper

            % --- Parse value_shown to determine ground truth ---
            % value_shown is like '9+3=10' or '1+5=6'
            value_shown = row.value_shown{1};
            tokens = regexp(value_shown, '(\d+)\+(\d+)=(\d+)', 'tokens');
            if ~isempty(tokens)
                a        = str2double(tokens{1}{1});
                b        = str2double(tokens{1}{2});
                shown    = str2double(tokens{1}{3});
                expected = (a + b == shown);  % true if arithmetic is correct, false if not
            else
                warning('Could not parse value_shown: %s at row %d', value_shown, i);
                continue
            end

            % --- Compare Whisper response to ground truth ---
            entered_bool = logical(entered);
            is_correct   = (entered_bool == expected);

            % --- Update table ---
            T.entered_value{i} = entered;
            T.correct{i}       = num2str(is_correct);

            % --- Update JSON field ---
            row_json         = jsondecode(T.json{i});
            row_json.entered = entered;
            row_json.correct = is_correct;
            T.json{i}        = jsonencode(row_json);
        end
    end
end

    %% --------------------------
    % --- Save updated CSV ---
    %% --------------------------
    writetable(T, output_csv, ...
        'Delimiter', ',', ...
        'QuoteStrings', true);

    fprintf('✅ Updated CSV saved to: %s\n', output_csv);

end

fprintf('\n🎉 All files processed successfully.\n');

end