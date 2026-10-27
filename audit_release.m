function report = audit_release()
%AUDIT_RELEASE Inspect dependencies and loaded text fields without modifying data.
    root = fileparts(mfilename('fullpath'));
    sources = dir(fullfile(root,'matlab','*.m'));
    paths = fullfile({sources.folder},{sources.name});
    [dependencies,products] = matlab.codetools.requiredFilesAndProducts(paths);
    external = dependencies(~startsWith(dependencies,root));
    report.external_dependency_count = numel(external);
    report.required_products = {products.Name};
    report.matlab_version = version;
    report.platform = computer;
    report.suspicious_text_fields = {};
    runs = dir(fullfile(root,'runs','*','validation_report.json'));
    report.exact_archived_trajectory_match = [];
    if ~isempty(runs)
        [~,latest] = max([runs.datenum]);
        run_root = runs(latest).folder;
    else
        run_root = '';
    end
    mats = dir(fullfile(root,'matlab','results','*.mat'));
    for i = 1:numel(mats)
        data = load(fullfile(mats(i).folder,mats(i).name));
        report.suspicious_text_fields = [report.suspicious_text_fields, ...
            scan_text(data,mats(i).name)]; %#ok<AGROW>
        if ~isempty(run_root)
            rebuilt = load(fullfile(run_root,'results',mats(i).name),'results');
            report.exact_archived_trajectory_match(i) = isequaln(data.results,rebuilt.results);
        end
    end
    assert(isempty(report.suspicious_text_fields),'Review flagged MAT text fields.');
    assert(isempty(external),'Dependencies outside the release need review.');
    fprintf('%s\n',jsonencode(report,'PrettyPrint',true));
    fid = fopen(fullfile(root,'DEPENDENCIES.json'),'w');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end

function flags = scan_text(value,label)
    flags = {};
    if isstruct(value)
        fields = fieldnames(value);
        for j = 1:numel(value)
            for k = 1:numel(fields)
                flags = [flags, scan_text(value(j).(fields{k}),[label '.' fields{k}])]; %#ok<AGROW>
            end
        end
    elseif istable(value)
        for key = string(value.Properties.VariableNames)
            flags = [flags,scan_text(value.(key),[label '.' char(key)])]; %#ok<AGROW>
        end
        flags = [flags,scan_text(value.Properties.Description,[label '.Description']), ...
            scan_text(value.Properties.UserData,[label '.UserData'])];
    elseif iscell(value)
        for j=1:numel(value)
            flags=[flags,scan_text(value{j},label)]; %#ok<AGROW>
        end
    elseif ischar(value) || isstring(value)
        pattern = '([A-Za-z]:\\|/Users/|/home/|sk-[A-Za-z0-9]{12,}|github_pat_|ghp_[A-Za-z0-9]+|-----BEGIN .*PRIVATE KEY)';
        if any(~cellfun(@isempty,regexp(cellstr(string(value)),pattern,'once')))
            flags = {label};
        end
    end
end
