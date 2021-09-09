# Nox
 
Utilities (Matlab) for accessing Noxmedical, Noxturnal  https://noxmedical.com/products/noxturnal-software/ data files .ndf.  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND... (MIT license)

# .ndb

Event files are SQLite format. You can use e.g. https://sqlitebrowser.org/ to read files.

# .ndf
Matlab reading and writing [ndf.m](ndf.m). Incomplete reverse engineering of file format. You can download demonstration recordings from https://support.noxmedical.com/hc/en-us/sections/201822583-PG-Demonstration-Recordings.

```
1) Reading ndf

nox=ndf('')               % dialog
nox=ndf('Pressure.ndf')   % load data
datestr(nox.start)

2) Writing ndf. Provide complete ascii .header or needed fields

nox.Type='Sine100Hz-100uv'; 
nox.Unit='V'          % default
nox.Label=nox.Type;   % default   
nox.Format='Int16'    % default
nox.Offset=0;         % default
nox.start=floor(now()*24*60*2)/(24*60*2);
nox.Scale=1e-6;
nox.SamplingRate=100;
t=1/nox.SamplingRate:1/nox.SamplingRate:90;
d=[];                 % 1-100 Hz, 100 uV
for f=1:1:100,        
  d=[d sin(2*pi.*t*f)*100e-6];
end
nox.data=d;           % create ndf file
ndf('Sine100Hz-100uV.ndf',nox);  
```


```
