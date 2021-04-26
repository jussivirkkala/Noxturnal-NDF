# Nox
 
Simple utilities for accessing Noxturnal  https://noxmedical.com/products/noxturnal-software/ data files .ndf.  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND... (MIT license)

Matlab reading and writing [ndf.m](ndf.m)

```
1) Reading ndf

nox=ndf('')               % dialog
nox=ndf('Pressure.ndf')   % load data
datestr(nox.start)

2) Writing ndf. Provide complete ascii .header or needed fields

nox=[];
nox.Type='EOG.MS'; 
nox.Unit='V'          % default
nox.Label=nox.Type;   % default   
nox.Format='Int16'    % default
nox.Offset=0;
nox.start=floor(now()*24*60*2)/(24*60*2);
nox.Scale=1e-6;
nox.SamplingRate=100;
t=1/nox.SamplingRate:1/nox.SamplingRate:90;
d=[];
for f=1:1:100,
d=[d sin(2*pi.*t*f)*100e-6];
end
nox.data=d;
ndf('trace.ndf',nox);  % create NDF file
```


```
