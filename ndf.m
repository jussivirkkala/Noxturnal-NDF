function nox=ndf(file,nox,field)
% Loading and writing Noxturnal (www.noxmedical.com) data file ndf. THE SOFTWARE 
% IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND... (MIT license)
%
% ndf                           % help ndf
%
% 1) Reading ndf
%
% signal=ndf('')                % dialog
% pressure=ndf('Pressure.ndf') 
% load data
% datestr(pressure.start)
% datestr(pressure.end)
%
% Plotting. Notice that data can contain multiple blocks. Handling of
% blocks is changed 2024-04-05. 
%
% plot(pressure.t,pressure.data);
% ylabel([label ' (uV)'])
% datetick('x','HH.MM.SS','keeplimits')  
%
% 2) Writing ndf. Provide complete .header_uint16 or .header or needed fields.
%
% clear nox
% nox.Type='Sine100Hz-100uv'; 
% nox.Unit='V'          % default
% nox.Label=nox.Type;   % default   
% nox.Format='Int16'    % default
% nox.Offset=0;         % default
% nox.start=floor(now()*24*60*2)/(24*60*2);
% nox.Scale=1e-6;
% nox.SamplingRate=100;
% t=1/nox.SamplingRate:1/nox.SamplingRate:90;
% d=[];                 % 1-100 Hz, 100 uV
% for f=1:1:100,        
%   d=[d sin(2*pi.*t*f)*100e-6];
% end
% nox.data=d;           % create ndf file
% ndf('Sine100Hz-100uV.ndf',nox);  

% @jussivirkkala
% 2025-03-10 Commenting out corrupt file.
% 2024-06-05 Writing blocks
% 2024-04-05 Breaking change of blocks. 
% 2023-05-13 Reading corrupt file. Description of us
% 2021-04-26 Adding .file field.
% 2021-04-22 Writing Noxturnal ndf files.
% 2021-01-18 Reading Noxturnal ndf files.
% 2020-12-29 File format reverse engineering.

if nargin==0,
    help(mfilename)
    return
end

%% Dialog for file, different commands
%
if ischar(file),
    if length(file)==0, % Reading file
        [fileName, pathName] = uigetfile({'*.ndf','*.ndf'},'Select Noxturnal ndf file');
        if fileName==0,
            error('Canceled')
            return
        else
            file=[pathName fileName];
        end
    end
    if nargin==2, % Writing file
        if exist(file,'file')
            error(['File ' file ' already exist']);
        end          
        nox=write_nox(file,nox);
    else        
        if ~exist(file,'file'),
            error(['No file: ' file]);
        end
        nox=read_nox(file);
    end
else
    cmd=upper(nox);
    nox=file;
    switch upper(cmd)
        otherwise
            fclose(f);
            error(['Unknown command ' cmd]);
    end
    return
end

%% Checking for field
%
function check(nox,field)
if isfield(nox,field),
    error(['Supporting only single field: ' field])
end

%% Reading file
%
function nox=read_nox(file)
f=fopen(file,'rb');
h=fread(f,4,'uint8');

if sum(abs(h-[78;79;88;3])) % NOX
    error('Not ndf file, should start with NOX')
end

nox=[];
nox.file=file;
nox.t={}; % 2024-03-26 Changed output
nox.data={};
nox.start=[];
nox.end=[];
nox.gap=[];
nox.samplingRateDouble=[];
nox.fields.len=[];
nox.fields.type=[];
nox.fields.pos=[];
nox.start_raw={};
nox.warning={};

while not(feof(f)),    
    % Type and length
    nox.fields.pos(end+1)=ftell(f);
    typ=fread(f,1,'uint16');
    if isempty(typ), % 2023-11-04
        nox.warning{end+1}='empty type';
    else
        nox.fields.type(end+1)=typ;
    end
    if ~isempty(typ),
        len=fread(f,1,'uint32');
        % if len==3780340,len=936800,end
        if isempty(len),
            nox.warning{end+1}='empty length';
            break;
        end
        nox.fields.len(end+1)=len;
        switch typ
            case 144 
                check(nox,'field144');
                % nox.field144Pos=ftell(f);
                nox.field144=fread(f,1,'double');
            case 1 % hash
                check(nox,'hash');
                d=fread(f,len/2,'uint16');
                nox.hash=char(d)';            
            case 512 % start time
                d=fread(f,len/2,'uint16');
                nox.start_raw{end+1}=char(d)';
                if len~=44,
                    disp(['start time ' nox.start_raw{end} ' length should be 44, not ' int2str(len) ' pos ' int2str(nox.fields.pos(end))]  ),
                end
                if len>39 & len<45, % len==44, 
                    nox.start(end+1)=datenum(char(d)','yyyymmddTHHMMSS.FFF'); % SKIPPING MICRO SECOND RESOLUTION
                else
                    error(strcat(char(d)'," start time not correct"))
                    % nox.start(end+1)=datenum(char(d)','yyyymmddTHHMMSS'); % CORRUPT FILE 
                end
                if length(nox.start)>1,
                    nox.gap(end+1)=(nox.start(end)-nox.end(end))*24*3600;
                end
            case 256 % header
                check(nox,'header');
                nox.header_pos=ftell(f);
                d=fread(f,len/2,'uint16');
                nox.header_uint16=d;              
                nox.header=char(d(find(d~=0))');
                % 2023-08-08 Usually contains extra zeros
                if sum(d==0),
                    % warning('header 0 values')
                    % nox.warning{end+1}='header 0 values';
                end
                nox.header=strrep(nox.header,'°','Angle'); 

                xmlStream = java.io.StringBufferInputStream(nox.header);
                xDoc = xmlread(xmlStream);
                for i=0:xDoc.item(0).getChildNodes.getLength-1,
                    n=xDoc.item(0).getChildNodes.item(i).getTagName;
                    n=char(n);
 % <Properties>
 % <Item><Key>Device_Serial</Key><Type>System.String</Type><Value>20080298</Value></Item>
 % <Item><Key>Device_Type</Key><Type>System.String</Type><Value>T3</Value></Item>
 % <Item><Key>Device_Firmware</Key><Type>System.String</Type><Value>1.3.0.7dc90a05e0d9_Donbot</Value></Item>
 % <Item><Key>Device_Version</Key><Type>System.String</Type><Value>1.0</Value></Item>
 % <Item><Key>Analog_Firmware</Key><Type>System.String</Type><Value>72</Value></Item>
 % <Item><Key>Analog_Version</Key><Type>System.String</Type><Value>3</Value></Item>
 % <Item><Key>Data_Encryption</Key><Type>System.Int32</Type><Value>1</Value></Item>
 % <Item><Key>Data_Licensee</Key><Type>System.String</Type><Value>Generic</Value></Item>
 % <Item><Key>Oximeter_Serial</Key><Type>System.String</Type><Value>144587</Value></Item>
 % <Item><Key>HASH</Key><Type>System.String</Type><Value>33379607-c3c1-4066-87bf-f23bb6a450e9</Value></Item><Item>
 % <Key>Version</Key><Type>System.Int32</Type><Value>2</Value></Item></Properties>
                    if strcmp(n,'Properties'),
                        for j=0:xDoc.item(0).getChildNodes.item(i).getLength-1,                        
                            properties=char(xDoc.item(0).getChildNodes.item(i).item(j).getChildNodes.item(0).item(0).getNodeValue);                   
                            value=char(xDoc.item(0).getChildNodes.item(i).item(j).getChildNodes.item(2).item(0).getNodeValue);                      
                            nox.Properties.(properties)=value;
                        end
                    else
                        if ~isempty(xDoc.item(0).getChildNodes.item(i).item(0)),
                            v=xDoc.item(0).getChildNodes.item(i).item(0).getNodeValue;
                            v=char(v);
                            check(nox,n);
                            nox.(n)=v;
                        end
                    end
                end
                nox.Scale=eval(nox.Scale); % Numerical values
                nox.Offset=eval(nox.Offset);
                nox.SamplingRate=eval(nox.SamplingRate);
            case 513 % Data
                switch nox.Format
                    case 'Byte'
                        d=fread(f,len,'uint8');
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];                                  
                    case 'ByteMuLaw'
                        d=fread(f,len,'uint8');
                        d=mu2lin(d);
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];                    
                    case 'Int16'
                        d=fread(f,len/2,'int16');
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];
                    case 'UInt32'
                        d=fread(f,len/4,'uint32');
                        % nox.data=[nox.data;
                        nox.data{end+1}=d*nox.Scale+nox.Offset;
                    case 'Int32'
                        d=fread(f,len/4,'int32');
                        % nox.data=[nox.data;
                        nox.data{end+1}=d*nox.Scale+nox.Offset;
                    case 'Double'
                        d=fread(f,len/8,'double');
                        % nox.data=[nox.data;
                        nox.data{end+1}=d*nox.Scale+nox.Offset;                        
                    otherwise
                        error(['Unsupported format ' num2str(nox.Format)])
                    if length(data)~=len,nox.warning{end+1}='length mismatch',end
                end
                if len>0
                    % nox.t=[nox.t; 2024-03-26 Breaking change
                    nox.t{end+1}=[nox.start(end)+(0:1:(length(d)-1))'/24/3600/nox.SamplingRate]; 
                    nox.end(end+1)=nox.t{end}(end);
                else
                    disp('Length 0');
                end
            case 514 % Sampling rate double
                % nox.samplingRateDoublePos=ftell(f);
                nox.samplingRateDouble(end+1)=fread(f,1,'double');
            otherwise
                nox.(['field' num2str(typ)])=fread(f,len,'uint8');
                disp(['Unknown type ' num2str(typ), ' len ' num2str(len) ' pos ' int2str(nox.fields.pos(end)) ]);
        end
    % Correcting
        if length(nox.fields.len)==4,
           %fseek(f,4,0)
        end    
    end
end
fclose(f);
nox.segments=length(nox.t);

%% Writing Noxturnal file
% 2024-04-05 Writing raw data 
function nox=write_nox(file,nox)

if ~isfield(nox,'header'),
    if ~isfield(nox,'Label'),nox.Label=nox.Type;end 
    if ~isfield(nox,['Un' ...
            '' ...
            'it']),nox.Unit='V';end
    if ~isfield(nox,'Format');nox.Format='Int16';end
    if ~isfield(nox,'Offset'),nox.Offset=0;end
    if ~isfield(nox,'Scale'),nox.Scale=1;end
    if ~isfield(nox,'start'),nox.start=now;end
    if ~isfield(nox,'samplingRateDouble'),nox.samplingRateDouble=nox.SamplingRate;end
    
    % header 256
    s=strcat('<Channel><Name>NOX</Name><Label>',nox.Label,'</Label><SourceType>Raw</SourceType>');
    s=strcat(s,'<Unit>',nox.Unit,'</Unit><HASH /><Source /><DeviceID /><DeviceSerial /><ChannelNumber>-1</ChannelNumber>');
    s=strcat(s,'<Format>',nox.Format,'</Format><Function />');
    s=strcat(s,'<IsBipolar>1</IsBipolar><IsDC>0</IsDC><IsRespiratory>0</IsRespiratory><ImpedanceCheck>0</ImpedanceCheck>');
    s=strcat(s,'<Scale>',num2str(nox.Scale),'</Scale><Offset>',num2str(nox.Offset),'</Offset>');
    s=strcat(s,'<Type>',nox.Type,'</Type>');
    s=strcat(s,'<SamplingRate>',num2str(nox.SamplingRate),'</SamplingRate>');
    s=strcat(s,'<Properties><Item><Key>AutomaticDerivedSignal</Key><Type>System.Boolean</Type><Value>True</Value></Item></Properties></Channel>');
else
    if isfield(nox,'Type'),
        error('Have either complete .header or necessary fields. Use trace=rmfield(trace,''header/Type'')');
    end
    s=nox.header;    
end

% start of file 78, 79, 88, 3
f=fopen(file,'wb');
fwrite(f,[78;79;88;3],'uint8');

% header
% if isfield
s=char(s); % 2026-05-04
s(end+1)=0;
fwrite(f,256,'uint16');
fwrite(f,length(s)*2,'uint32');
fwrite(f,s,'uint16'); % 2024-06-05
nox.header=s;

% multiple segments
if ~iscell(nox.data)
     nox.data={nox.data};
end
nox.segments=length(nox.data);

for i=1:nox.segments
    % time 512
    fwrite(f,512,'int16');
    % only ms resolution, format supports us
    s=datestr(nox.start(i),'yyyymmddTHHMMSS.FFF000');
    fwrite(f,length(s)*2,'uint32');
    fwrite(f,s,'int16');

    % sampling rate 514
    fwrite(f,514,'int16'); 
    fwrite(f,8,'uint32');
    fwrite(f,nox.samplingRateDouble(i),'double');  % 2024-06-06

    % data 513
    data=double(nox.data{i});
    fwrite(f,513,'int16');
    switch nox.Format
        case 'Byte'
            fwrite(f,length(data),'byte');
            fwrite(f,(data-nox.Offset)/nox.Scale,'byte');
        case 'Int16'
            fwrite(f,length(data)*2,'uint32');
            fwrite(f,(data-nox.Offset)/nox.Scale,'int16');
        case 'Int32'
            fwrite(f,length(data)*4,'uint32');
            fwrite(f,(data-nox.Offset)/nox.Scale,'int32');
        case 'Double'
            fwrite(f,length(data)*8,'uint32');
            fwrite(f,(data-nox.Offset)/nox.Scale,'double');
        otherwise
            error(['Unsupported format ' nox.Format])
    end
end
fclose(f);

%% end