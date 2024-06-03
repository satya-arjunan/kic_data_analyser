% CLASS DESCRIPTION 
%
% NOTES:
%
% RELEASE VERSION: 0.6
%
% AUTHOR: Anton Shpak (a.shpak@victorchang.edu.au)
%
% DATE: February 2020
classdef FileReader
    
    properties (Constant)
        Table_VariableName_CellID_Prefix = "CellID_";
    end
    
    methods (Static)

        function fileFullName = SelectDataFile()
            fileFullName = "";
            
            % open file dialog
            [file, path, ~] = uigetfile('*.csv', 'Select a *.csv Data File');
            if (~isequal(file, 0))
                doubleFileSep = strcat(filesep, filesep);
                fileFullName = strrep(strrep(string(fullfile(path, file)), doubleFileSep, filesep), filesep, doubleFileSep);

                [~, ~, fileExt] = fileparts(fileFullName);
                if (~isequal(fileExt, ".csv"))
                    Log.ErrorMessage(0, "Error: Please, select a *.csv file");
                    fileFullName = "";
                end
            end
            
        end
        
        function T = ReadFileToTable(fileFullName)
            
            if (exist(fileFullName, 'file') ~= 2)
                throw(MException(Error.ID_ReadFileError, strcat(Error.Msg_ReadFileError_NotExist, " ", fileFullName)));
            end
            
            try
                startReadFile = Log.StartBlock(1, strcat("Started reading file '", fileFullName, "'"));
                
                % read whole file to detect number of cells in the file
                opts = detectImportOptions(fileFullName);
                opts.Delimiter = ',';
                opts = setvartype(opts, 'char');
                opts = setvaropts(opts, 'FillValue', '');
                opts.DataLines = [1 Inf];
                opts.EmptyLineRule = 'read'; 

                T1 = readtable(fileFullName, opts);

                % extract date and description
                date = datetime(string(table2cell(T1(2, 2))), 'InputFormat', 'MMMM dd yyyy HH:mm:ss');
                description = string(table2cell(T1(3, 2)));

                % detect header row
                headerRowIndex = 0;
                while(headerRowIndex < size(T1, 1))
                    headerRowIndex = headerRowIndex + 1;
                    
                    if (string(table2cell(T1(headerRowIndex, 1))) == "id" &&...
                        string(table2cell(T1(headerRowIndex, 2))) == "T (index)" &&...
                        string(table2cell(T1(headerRowIndex, 3))) == "T (msec)")
                        break;
                    end
                end
                
                % if header row not found - return empty table
                if (headerRowIndex == size(T1, 1))
                    T = array2table(zeros(0, 1));
                    return;
                end

                % read second part of the file
                opts = detectImportOptions(fileFullName, 'NumHeaderLines', headerRowIndex - 1, 'ReadVariableNames', true);
                opts = setvartype(opts, 'double');
                opts = setvaropts(opts, 'FillValue', NaN);
                opts.VariableNamesLine = headerRowIndex;
                opts.DataLines = [headerRowIndex + 1 Inf];

                T = readtable(fileFullName, opts);
                
                % replace VariableNames (i.e. Cell's Column Names with
                % prefix + ID: "CellID_" + cellID (example: CellID_33)
                for i = 4 : size(T, 2)
                    cellName = T.Properties.VariableNames{i};

                    strCellIDs = regexp(cellName, '\d*', 'match');

                    % if cell header doesn't contain a number - assign cellID as
                    % (10000 + column number), to easily locate in source csv file
                    cellID = num2str(10000 + i);
                    if (~isempty(strCellIDs))
                        cellID = strCellIDs(1);
                    end
                    
                    T.Properties.VariableNames{i} = char(cellstr(strcat(FileReader.Table_VariableName_CellID_Prefix, cellID)));
                end

                % add custom properties
                T = addprop(T, {'Date','Description', 'FileFullName'},{'table', 'table', 'table'});
                T.Properties.CustomProperties.Date = date;
                T.Properties.CustomProperties.Description = description;
                
                T.Properties.CustomProperties.FileFullName = fileFullName;
                
                Log.EndBlock(startReadFile, 1, strcat("Finished reading file '", fileFullName, "'"));
                
            catch ME
                Log.ErrorMessage(1, strcat("Failed to read file '", fileFullName, "'"));
                
                ex = MException(Error.ID_ReadFileError, strcat(Error.Msg_ReadFileError, '\r', ME.identifier, "\r", ME.message));
                throw(ex);
            end
        end
        
    end
end

