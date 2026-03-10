
classdef VNA_MultiPlotApp < handle
    properties
        UIFig
        Ax
        btnLoad
        lbFiles
        ddSParam
        btnPlot
        lbTraces
        ddOperation
        btnCompute
        btnExportImage
        btnExportCSV
        btnDelete
        btnRename

        % Styling controls
        ddLineStyle
        ddMarker
        spLineWidth
        btnColor
        btnApplyStyle
        btnGrid
        btnAxBG
        spFontSize
        %ddLegendPos

        dataStore
        plottedLines
        derivedData
    end

    methods
        function app = VNA_MultiPlotApp()
            createUI(app);
        end

        function createUI(app)
            app.UIFig = uifigure('Name','VNA Multi-File App','Position',[200 200 1100 640]);
            % after creating app.UIFig
            app.UIFig.KeyPressFcn = @(src,event) onKeyPress(app,src,event);

            % Axes
            app.Ax = uiaxes(app.UIFig,'Position',[380 80 700 540]);
            xlabel(app.Ax,'Frequency (GHz)');
            ylabel(app.Ax,'Magnitude (dB)');
            grid(app.Ax,'on');
            title(app.Ax,'VNA Overlay');

            % File/load controls
            app.btnLoad = uibutton(app.UIFig,'push','Text','Load CSV Files',...
                'Position',[20 560 320 30],'ButtonPushedFcn',@(~,~)app.onLoad());
            app.lbFiles = uilistbox(app.UIFig,'Position',[20 380 320 170],...
                'Multiselect','on','Tooltip','Loaded files');
            app.lbTraces.KeyPressFcn = @(s,e) onListKey(app,s,e);


            % S-parameter and plot
            app.ddSParam = uidropdown(app.UIFig,'Items',{'S11','S12','S21','S22'},...
                'Position',[20 340 150 30],'Value','S11');
            app.btnPlot = uibutton(app.UIFig,'push','Text','Plot Selected',...
                'Position',[190 340 150 30],'ButtonPushedFcn',@(~,~)app.onPlot());

            % Traces list and operations
            uilabel(app.UIFig,'Text','Traces (for ops & styling):','Position',[20 310 200 20]);
            app.lbTraces = uilistbox(app.UIFig,'Position',[20 180 320 130],'Multiselect','on');

            app.ddOperation = uidropdown(app.UIFig,'Items',{'Add','Subtract'},...
                'Position',[20 140 150 30],'Value','Add');
            app.btnCompute = uibutton(app.UIFig,'push','Text','Compute Operation',...
                'Position',[190 140 150 30],'ButtonPushedFcn',@(~,~)app.onCompute());

            % Export controls
            app.btnExportImage = uibutton(app.UIFig,'push','Text','Export Image',...
                'Position',[20 100 150 30],'ButtonPushedFcn',@(~,~)app.onExportImage());
            app.btnExportCSV = uibutton(app.UIFig,'push','Text','Export CSV',...
                'Position',[190 100 150 30],'ButtonPushedFcn',@(~,~)app.onExportCSV());

            % Delete / Rename
            app.btnDelete = uibutton(app.UIFig,'push','Text','Delete Trace',...
                'Position',[20 60 150 30],'ButtonPushedFcn',@(~,~)app.onDelete());
            app.btnRename = uibutton(app.UIFig,'push','Text','Rename Trace',...
                'Position',[190 60 150 30],'ButtonPushedFcn',@(~,~)app.onRename());

            % Styling controls (bottom row)
            app.ddLineStyle = uidropdown(app.UIFig,'Items',{'-','--',':','-.'},...
                'Position',[380 20 80 30],'Value','-','Tooltip','Line style');
            app.ddMarker = uidropdown(app.UIFig,'Items',{'none','o','s','^','+','x'},...
                'Position',[470 20 80 30],'Value','none','Tooltip','Marker');
            app.spLineWidth = uispinner(app.UIFig,'Limits',[0.5 10],'Step',0.5,'Value',1.5,...
                'Position',[560 20 80 30],'Tooltip','Line width');
            app.btnColor = uibutton(app.UIFig,'push','Text','Color...','Position',[650 20 80 30],...
                'ButtonPushedFcn',@(~,~) onChooseColor(app),'Tooltip','Choose line color');
            app.btnApplyStyle = uibutton(app.UIFig,'push','Text','Apply Style',...
                'Position',[740 20 100 30],'ButtonPushedFcn',@(~,~) applyStyle(app),'Tooltip','Apply style to selected traces');

            % Axes appearance controls
            app.btnGrid = uibutton(app.UIFig,'state','Text','Grid','Position',[860 20 60 30],...
                'Value',true,'ValueChangedFcn',@(s,e) onToggleGrid(app,s.Value),'Tooltip','Toggle grid');
            app.btnAxBG = uibutton(app.UIFig,'push','Text','BG Color','Position',[930 20 80 30],...
                'ButtonPushedFcn',@(~,~) onChooseAxBG(app),'Tooltip','Change axes background color');
            app.spFontSize = uispinner(app.UIFig,'Limits',[6 24],'Value',10,'Position',[1020 20 60 30],...
                'ValueChangedFcn',@(s,~) onFontSize(app,s.Value),'Tooltip','Font size for labels/title');

            %app.ddLegendPos = uidropdown(app.UIFig,'Items',{'best','north','south','east','west','northeast','northwest'},...
            %    'Position',[660 60 140 30],'Value','best','ValueChangedFcn',@(d,~) set(app.Ax,'LegendLocation',d.Value),...
            %    'Tooltip','Legend location'); % messes up the layout

            % Data structures
            app.dataStore = struct('filename',{},'freq',{},'S11',{},'S12',{},'S21',{},'S22',{});
            app.plottedLines = gobjects(0);
            app.derivedData = [];
        end
        function onLoad(app)
            [files,path] = uigetfile('*.csv','Select VNA CSV files','MultiSelect','on');
            if isequal(files,0), return; end
            if ischar(files), files = {files}; end

            for k=1:numel(files)
                fname = fullfile(path,files{k});
                % read until a line that looks like data header or contains 'PNT'
                fid = fopen(fname,'r');
                headerLines = 0;
                line = '';
                while ischar(line) || headerLines==0
                    line = fgetl(fid);
                    headerLines = headerLines + 1;
                    if ~ischar(line), break; end
                    if contains(line,'PNT','IgnoreCase',true) || contains(line,',FREQ','IgnoreCase',true)
                        break;
                    end
                end
                fclose(fid);
                try
                    T = readtable(fname,'HeaderLines',max(0,headerLines-1));
                catch
                    uialert(app.UIFig,['Failed to read: ' files{k}],'Read Error');
                    continue;
                end
                colNames = T.Properties.VariableNames;
                idxFreq = find(contains(colNames,'FREQ','IgnoreCase',true),1);
                idxLog = find(contains(colNames,'LOGMAG','IgnoreCase',true));
                if isempty(idxFreq) || isempty(idxLog)
                    uialert(app.UIFig,['File missing expected columns: ' files{k}],'Column Error');
                    continue;
                end
                freq = T{:,idxFreq};
                logs = nan(size(T,1),4);
                for c=1:min(4,numel(idxLog))
                    logs(:,c) = T{:,idxLog(c)};
                end
                rec.filename = files{k};
                rec.freq = freq;
                rec.S11 = logs(:,1);
                rec.S12 = logs(:,2);
                rec.S21 = logs(:,3);
                rec.S22 = logs(:,4);
                app.dataStore(end+1) = rec; %#ok<AGROW>
            end
            app.lbFiles.Items = {app.dataStore.filename};
        end

        function onPlot(app)
            sel = app.lbFiles.Value;
            if isempty(sel)
                uialert(app.UIFig,'Select one or more files to plot','No Files Selected');
                return;
            end
            sparam = app.ddSParam.Value;
            cla(app.Ax);
            hold(app.Ax,'on');
            app.plottedLines = gobjects(0);
            app.lbTraces.Items = {};
            for k=1:numel(sel)
                idx = find(strcmp({app.dataStore.filename},sel{k}),1);
                if isempty(idx), continue; end
                rec = app.dataStore(idx);
                y = rec.(sparam);
                h = plot(app.Ax,rec.freq,y,'LineWidth',1.5,'DisplayName',rec.filename);
                app.plottedLines(end+1) = h; %#ok<AGROW>
                app.lbTraces.Items{end+1} = rec.filename; %#ok<AGROW>
            end
            hold(app.Ax,'off');
            lgd = legend(app.Ax,'show');
            lgd.Interpreter = 'none';
            lgd.Location = 'best';
        end

        function onCompute(app)
            sel = app.lbTraces.Value;
            if numel(sel)~=2
                uialert(app.UIFig,'Select exactly two traces for operation','Selection Error');
                return;
            end
            idx1 = find(strcmp({app.dataStore.filename},sel{1}),1);
            idx2 = find(strcmp({app.dataStore.filename},sel{2}),1);
            if isempty(idx1)||isempty(idx2)
                uialert(app.UIFig,'Selected traces must be loaded files','Selection Error');
                return;
            end
            rec1 = app.dataStore(idx1);
            rec2 = app.dataStore(idx2);
            sparam = app.ddSParam.Value;
            x1 = rec1.freq; y1 = rec1.(sparam);
            x2 = rec2.freq; y2 = rec2.(sparam);
            fmin = max(min(x1),min(x2));
            fmax = min(max(x1),max(x2));
            if fmin>=fmax
                fq = unique([x1;x2]);
            else
                n = max(numel(x1),numel(x2));
                fq = linspace(fmin,fmax,n).';
            end
            y1i = interp1(x1,y1,fq,'pchip',NaN);
            y2i = interp1(x2,y2,fq,'pchip',NaN);
            op = app.ddOperation.Value;
            switch op
                case 'Add'
                    yout = y1i + y2i;
                    lab = sprintf('%s + %s',sel{1},sel{2});
                case 'Subtract'
                    yout = y1i - y2i;
                    lab = sprintf('%s - %s',sel{1},sel{2});
            end
            app.derivedData.freq = fq;
            app.derivedData.mag = yout;
            app.derivedData.label = lab;
            hold(app.Ax,'on');
            ph = plot(app.Ax,fq,yout,'k','LineWidth',1.8,'DisplayName',lab);
            hold(app.Ax,'off');
            app.lbTraces.Items{end+1} = lab;
            app.lbTraces.Value = {sel{1},sel{2},lab};
            lgd = legend(app.Ax,'show');
            lgd.Interpreter = 'none';
            lgd.Location = 'best';
            app.plottedLines(end+1) = ph;
        end
        function onExportImage(app)
            if isempty(app.plottedLines)
                uialert(app.UIFig,'Nothing plotted to export','No Plot');
                return;
            end

            % Choose a writable default folder (prefer user Documents/home)
            if isdeployed
                startFolder = getenv('USERPROFILE'); % Windows
                if isempty(startFolder), startFolder = getenv('HOME'); end % mac/linux
                if isempty(startFolder), startFolder = tempdir; end
            else
                startFolder = pwd;
            end

            if ~isfolder(startFolder)
                startFolder = tempdir;
            end

            [file,path] = uiputfile({'*.png';'*.jpg';'*.tif'},'Save Plot As', fullfile(startFolder,'plot.png'));
            if isequal(file,0), return; end
            fname = fullfile(path,file);

            % Make sure the directory exists and is writable
            if ~isfolder(path)
                [ok,msg] = mkdir(path);
                if ~ok
                    uialert(app.UIFig,['Cannot create folder: ' msg],'Export Error');
                    return;
                end
            end

            % Quick write test
            try
                testFile = fullfile(path, ['.__write_test_' char(java.util.UUID.randomUUID) '.tmp']);
                fid = fopen(testFile,'w');
                if fid == -1
                    error('Cannot write to folder: %s', path);
                end
                fprintf(fid,'test');
                fclose(fid);
                delete(testFile);
            catch ex
                uialert(app.UIFig,['Cannot write to selected folder: ' ex.message],'Permission Error');
                return;
            end

            try
                exportgraphics(app.Ax,fname,'Resolution',300);
                uialert(app.UIFig,['Saved image: ' fname],'Saved');
            catch ex
                uialert(app.UIFig,['Failed to export image: ' ex.message],'Export Error');
            end
        end


        function onExportCSV(app)
            if isempty(app.derivedData)
                uialert(app.UIFig,'No derived data to export. Compute an operation first.','No Data');
                return;
            end

            if isdeployed
                startFolder = getenv('USERPROFILE');
                if isempty(startFolder), startFolder = getenv('HOME'); end
                if isempty(startFolder), startFolder = tempdir; end
            else
                startFolder = pwd;
            end
            if ~isfolder(startFolder)
                startFolder = tempdir;
            end

            [file,path] = uiputfile('*.csv','Save Derived CSV', fullfile(startFolder,'derived.csv'));
            if isequal(file,0), return; end
            fname = fullfile(path,file);

            if ~isfolder(path)
                [ok,msg] = mkdir(path);
                if ~ok
                    uialert(app.UIFig,['Cannot create folder: ' msg],'Export Error');
                    return;
                end
            end

            % Quick write test
            try
                testFile = fullfile(path, ['.__write_test_' char(java.util.UUID.randomUUID) '.tmp']);
                fid = fopen(testFile,'w');
                if fid == -1
                    error('Cannot write to folder: %s', path);
                end
                fprintf(fid,'test');
                fclose(fid);
                delete(testFile);
            catch ex
                uialert(app.UIFig,['Cannot write to selected folder: ' ex.message],'Permission Error');
                return;
            end

            T = table(app.derivedData.freq,app.derivedData.mag, 'VariableNames',{'Frequency_GHz','Magnitude_dB'});
            try
                writetable(T,fname);
                uialert(app.UIFig,['Saved CSV: ' fname],'Saved');
            catch ex
                uialert(app.UIFig,['Failed to save CSV: ' ex.message],'Error');
            end
        end

        function onDelete(app)
            sel = app.lbTraces.Value;
            if isempty(sel)
                uialert(app.UIFig,'Select one or more traces to delete','No Selection');
                return;
            end
            sel = string(sel);
            for k = 1:numel(sel)
                lbl = sel(k);
                % Delete plotted objects with matching DisplayName
                matches = findobj(app.Ax,'-property','DisplayName');
                for h = matches(:).'
                    if string(get(h,'DisplayName')) == lbl
                        delete(h);
                        app.plottedLines(ismember(app.plottedLines,h)) = [];
                    end
                end
                % Derived data label
                if isfield(app.derivedData,'label') && string(app.derivedData.label) == lbl
                    app.derivedData = [];
                end
                % Remove from trace list
                items = string(app.lbTraces.Items);
                items(items == lbl) = [];
                app.lbTraces.Items = items;
            end
            lgd = legend(app.Ax,'show');
            lgd.Interpreter = 'none';
            lgd.Location = 'best';
        end

        function onRename(app)
            sel = app.lbTraces.Value;
            if isempty(sel)
                uialert(app.UIFig,'Select exactly one trace to rename','Selection Error');
                return;
            end
            sel = string(sel);
            if numel(sel)~=1
                uialert(app.UIFig,'Select exactly one trace to rename','Selection Error');
                return;
            end
            old = sel(1);
            answer = inputdlg({'Enter new name:'}, 'Rename Trace', 1, {char(old)});
            if isempty(answer), return; end
            new = string(answer{1});
            % Update plotted object DisplayName(s)
            matches = findobj(app.Ax,'-property','DisplayName');
            for h = matches(:).'
                if string(get(h,'DisplayName')) == old
                    set(h,'DisplayName',char(new));
                end
            end
            % Update derivedData label if matches
            if isfield(app.derivedData,'label') && string(app.derivedData.label) == old
                app.derivedData.label = char(new);
            end
            % Update list items
            items = string(app.lbTraces.Items);
            items(items == old) = new;
            app.lbTraces.Items = items;
            app.lbTraces.Value = new;
            lgd = legend(app.Ax,'show');
            lgd.Interpreter = 'none';
            lgd.Location = 'best';
        end

        function onChooseColor(app)
            c = uisetcolor;
            if isequal(c,0), return; end
            app.btnColor.UserData = c;
        end

        function applyStyle(app)
            sel = app.lbTraces.Value;
            if isempty(sel)
                uialert(app.UIFig,'Select one or more traces to style','No Selection');
                return;
            end
            sel = string(sel);
            ls = app.ddLineStyle.Value;
            mk = app.ddMarker.Value;
            lw = app.spLineWidth.Value;
            col = [];
            if ~isempty(app.btnColor.UserData)
                col = app.btnColor.UserData;
            end
            matches = findobj(app.Ax,'-property','DisplayName');
            for k=1:numel(sel)
                lbl = sel(k);
                for h = matches(:).'
                    if string(get(h,'DisplayName')) == lbl
                        set(h,'LineStyle',ls,'Marker',mk,'LineWidth',lw);
                        if ~isempty(col), set(h,'Color',col); end
                    end
                end
            end
        end

        function onToggleGrid(app,val)
            if val
                grid(app.Ax,'on');
            else
                grid(app.Ax,'off');
            end
        end

        function onChooseAxBG(app)
            c = uisetcolor(get(app.Ax,'Color'));
            if isequal(c,0), return; end
            set(app.Ax,'Color',c);
        end

        function onFontSize(app,sz)
            set(app.Ax,'FontSize',sz);
            set(get(app.Ax,'Title'),'FontSize',sz+2);
            set(get(app.Ax,'XLabel'),'FontSize',sz);
            set(get(app.Ax,'YLabel'),'FontSize',sz);
        end

        function delete(app)
            if isvalid(app.UIFig), delete(app.UIFig); end
        end
        function out = uipromptdlg(~, promptTxt, dlgTitle, defaultText)
            % Simple modal prompt dialog that returns a 1x1 cell with text or {} if cancelled.
            d = uifigure('Name',dlgTitle,'WindowStyle','modal','Position',[400 400 360 140]);
            uilabel(d,'Text',promptTxt,'Position',[15 90 330 30]);
            edt = uieditfield(d,'text','Position',[15 55 330 28],'Value',defaultText);
            btnOK = uibutton(d,'push','Text','OK','Position',[60 15 100 28]);
            btnCancel = uibutton(d,'push','Text','Cancel','Position',[200 15 100 28]);

            answer = [];
            btnOK.ButtonPushedFcn = @(~,~) setAnswer(true);
            btnCancel.ButtonPushedFcn = @(~,~) setAnswer(false);

            function setAnswer(ok)
                if ok
                    answer = {edt.Value};
                else
                    answer = {};
                end
                delete(d);
            end

            uiwait(d);
            out = answer;
        end
        function onKeyPress(app,~,event)
            % Only act when Delete (or Backspace, optional) is pressed and
            % the traces listbox has the focus.
            if isempty(event) || isempty(event.Key)
                return;
            end
            key = event.Key;
            if ~(strcmp(key,'delete') || strcmp(key,'backspace'))
                return;
            end
            % CurrentObject is the UI component that has focus in a uifigure
            try
                focused = app.UIFig.CurrentObject;
            catch
                focused = [];
            end
            if isequal(focused, app.lbTraces)
                app.onDelete();
            end
        end
        function onListKey(app,~,event)
            % Trigger delete only for Delete (or Backspace if desired)
            if isempty(event) || isempty(event.Key)
                return;
            end
            if strcmp(event.Key,'delete') || strcmp(event.Key,'backspace')
                % Ensure there is something selected
                if ~isempty(app.lbTraces.Value)
                    app.onDelete();
                end
            end
        end


    end
end
