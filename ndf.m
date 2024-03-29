function nox=ndf(file,nox,field)
% Loading and writing Noxturnal (www.noxmedical.com) data file ndf. THE SOFTWARE 
% IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND... (MIT license)
%
% ndf                       % help ndf
%
% 1) Reading ndf
%
% nox=ndf('')               % dialog
% nox=ndf('Pressure.ndf')   % load data
% datestr(nox.start)
% datestr(nox.end)
%
% Plotting. Notice that data can contain multiple blocks.
%
% plot(nox.t,nox.data);
% ylabel([label ' (uV)'])
% datetick('x','HH.MM.SS','keeplimits')  
%
% 2) Writing ndf. Provide complete ascii .header or needed fields.
% Currently not supporting multiple blocks.
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
% 2023-09-27 Writing multiple block
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
            error('File already exist');
        end          
        nox=write_nox(file,nox)
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
        case 'FIELD',
            for i=1:length(field),
            end
        otherwise
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
% 2021-04-22
function nox=read_nox(file)
f=fopen(file,'rb');
h=fread(f,4,'uint8');

if sum(abs(h-[78;79;88;3])) % NOX
    error('Not ndf file, should start with NOX')
end

nox=[];
nox.file=file;
nox.t=[];
nox.data=[];
nox.start=[];
nox.end=[];
nox.gap=[];
nox.samplingRateDouble=[];

while not(feof(f)),
    % Type and length
    typ=fread(f,1,'uint16');
    if ~isempty(typ),
        len=fread(f,1,'uint32');
        switch typ
            case 144 
                check(nox,'field144');
                nox.field144Pos=ftell(f);
                nox.field144=fread(f,1,'double');
            case 1 % hash
                check(nox,'hash');
                d=fread(f,len/2,'uint16');
                nox.hash=char(d)';            
            case 512 % start time
                d=fread(f,len/2,'uint16');
                if len==36,
                    warning("Start time length not correct")
                    nox.start(end+1)=datenum(char(d)','yyyymmddTHHMMSS'); % CORRUPT FILE 
                else
                    nox.start(end+1)=datenum(char(d)','yyyymmddTHHMMSS.FFF'); % MISSING MICRO SEOCOND RESOLUTION
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
                % 2023-08-08
                if sum(d==0),
                    warning('Header 0 values')
                end
                nox.header=strrep(nox.header,'�','Angle');
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
                        d=mu2lin(d);
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];                                  
                    case 'ByteMuLaw'
                        d=fread(f,len,'uint8');
                        d=mu2lin(d);
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];                    
                    case 'Int16'
                        d=fread(f,len/2,'int16');
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];
                    case 'Int32'
                        d=fread(f,len/4,'int32');
                        nox.data=[nox.data;d*nox.Scale+nox.Offset];
                    otherwise
                        error(['Unsupported format ' num2str(nox.Format)])
                end
                if len>0
                    nox.t=[nox.t;nox.start(end)+(0:1:(length(d)-1))'/24/3600/nox.SamplingRate]; 
                    nox.end(end+1)=nox.t(end);
                else
                    disp('Length 0');
                end
            case 514 % Sampling rate double
                nox.samplingRateDoublePos=ftell(f);
                nox.samplingRateDouble(end+1)=fread(f,1,'double');
            otherwise
                nox.(['field' num2str(typ)])=fread(f,len,'uint8');
                disp(['Unknown type ' num2str(typ), ' len ' num2str(len)]);
        end
    end
end
fclose(f);

%% Writing Noxturnal file
%
function nox=write_nox(file,nox)

if ~isfield(nox,'header'),
    if ~isfield(nox,'Label'),nox.Label=nox.Type;end 
    if ~isfield(nox,'Unit'),nox.Unit='V';end
    if ~isfield(nox,'Format');nox.Format='Int16';end
    if ~isfield(nox,'Offset'),nox.Offset=0;end
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
        error('You should either have complete .header or necessary fields');
    end
    s=nox.header;    
end
% start of file 78, 79, 88, 3
f=fopen(file,'wb');
fwrite(f,[78;79;88;3],'uint8');

s(end+1)=0;
fwrite(f,256,'uint16');
fwrite(f,length(s)*2,'uint32');
fwrite(f,s,'uint16');
nox.header=s;

% multiple segments

% time 512
fwrite(f,512,'int16');
% only ms resolution, format supports ns
s=datestr(nox.start,'yyyymmddTHHMMSS.FFF000');
fwrite(f,length(s)*2,'uint32');
fwrite(f,s,'int16');

% sampling rate 514
fwrite(f,514,'int16'); 
fwrite(f,8,'uint32');
fwrite(f,nox.SamplingRate,'double');  

% data 513
nox.data=double(nox.data);
fwrite(f,513,'int16');
fwrite(f,length(nox.data)*2,'uint32');
switch nox.Format
    case 'Int16'
        fwrite(f,(nox.data-nox.Offset)/nox.Scale,'int16');
    otherwise
        error(['Unsupported format ' nox.Format])
end
fclose(f);

%% end