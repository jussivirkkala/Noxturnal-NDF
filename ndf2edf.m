function hdr=ndf2edf(path,channels)
% Loading Noxturnal (noxmedical.com) ndf data files ndf and write as EDF. 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND... 
% (MIT license)
% 
% Uses ndf.m to read files. Tested with 2025-02-09 version. If channel
% is Int32 (A1S bipolar) or Double (R40) then then using HP 0.16 Hz. 
%
% Scaling signals -5 to 5 mV for Stratus EEG reader (stratuseeg.com).
%
% ndf2edf('\\folder\',{'1-ref','F-ref','2-ref','Fp1-ref','Fp2-ref','C3-ref','C4-ref','Cz-ref','E1-ref','E2-ref','F3-ref','F4-ref','F7-ref','F8-ref','Fz-ref','M1-ref','M2-ref','O1-ref','O2-ref','P3-ref','P4-ref','Pz-ref','T3-ref','T4-ref','T5-ref','T6-ref','bp1-gnd','bp2-gnd'}
%
% You can rename also .ndf files before conversion e.g. bp1-gnd->EKG, E1->LOC-ref, E2->ROC-ref, m1-ref->FT9-ref, m2-ref->FT10-ref 
%
% ndf2edf('\\folder\',{'F-ref','1-ref','2-ref','Fp1-ref','Fp2-ref','C3-ref','C4-ref','Cz-ref','F3-ref','F4-ref','F7-ref','F8-ref','Fz-ref','O1-ref','O2-ref','P3-ref','P4-ref','Pz-ref','T3-ref','T4-ref','T5-ref','T6-ref', 'FT9-ref','FT10-ref','EKG', 'LOC-ref', 'ROC-ref'})

% @jussivirkkala
% - Option for patient, recording
% 2025-02-11 Documentation
% 2025-01-11 Tested version
% 2025-02-09 First version

if nargin==0,
    help(mfilename)
    return
end

d0=ndf(strcat(path,channels{1},'.ndf'));
% each segment in separate EDF
for segment_index=1:d0.segments;
    % if (i>1) d0=ndf(strcat(path,channels{1},'.ndf'));end
    disp(['Segment ' int2str(segment_index) ' start time: ' datestr(d0.start(segment_index))])
    % Rounding sampling rate, could be problematic is some cases!
    sr=round(d0.samplingRateDouble(segment_index));
    % Filter
    [filter_b,filter_a]=butter(2,[0.16*2]/sr,'high');
    hdr = edfheader('EDF');

    hdr.NumDataRecords = floor(length(d0.data{segment_index})/sr);
    hdr.DataRecordDuration = seconds(1);
    channel_n=length(channels);
    hdr.NumSignals = channel_n;
    sigData = cell(channel_n,1);

    for channel_index=1:channel_n,
        disp(['converting ' path channels{channel_index}])
        % Read data
        d=ndf(strcat(path,channels{channel_index},'.ndf'));
        hdr.StartDate=datestr(d0.start(segment_index),'dd.mm.yy');
        hdr.StartTime=datestr(d0.start(segment_index),'HH.MM.SS');
        % Check data
        if ~strcmp(d.Unit,'V')
            error(strcat('Assuming Unit V not ',d.Unit))
        end

        if d0.start(segment_index)~=d.start(segment_index),
            error(['Change in start ' d.Label ' from ' d0.Label])
        end
        if round(d.samplingRateDouble(segment_index))~=sr,
            error(['Change in samplingRateDouble ' d.Label ' from ' d0.Label])
        end

        data=d.data{segment_index}*1e6;
        if d.Format=="Double" | d.Format=="Int32",
            hdr.Prefilter(end+1)="HP:0.16Hz";
            data=filter(filter_b,filter_a,data);
        else
            hdr.Prefilter(end+1)="";
        end

        hdr.SignalLabels(end+1)=[channels{channel_index}];
        hdr.PhysicalDimensions(end+1)="uV";

        data(data>5000)=5000;
        data(data<-5000)=-5000;
        sigData{channel_index}=data(1:hdr.NumDataRecords*sr);
        
        hdr.PhysicalMin(end+1) = -5000;
        hdr.PhysicalMax(end+1) = 5000;
        hdr.DigitalMin(end+1) = -32768;
        hdr.DigitalMax(end+1) = 32767;
    end
    % Write edf
    edfw = edfwrite(strcat(path,datestr(d.start(segment_index),30),'.edf'),hdr,sigData,'InputSampleType','physical');        
end

%% End       