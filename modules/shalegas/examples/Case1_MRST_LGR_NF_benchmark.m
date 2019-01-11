%% Case 1 Benchmark with CMG GEM
% In this example, we will demonstrate how one can easily extend the
% compressible single-phase pressure solver to include the effect of
% pressure-dependent viscosity using either arithmetic averaging of the
% viscosity or harmonic averaging of the fluid mobility.
% DataFolder: '\examples\Benchmark_CMG\'

close all; clear;
%PathConfigure;
mrstModule add hfm;             % hybrid fracture module
mrstModule add ad-props ad-core % AD framework
mrstModule add ad-blackoil      % Three phase simulator
mrstModule add shalegas

%% Define geometric quantitites
% Create explicit fracture grid with Log LGR
physdim = [1990*ft 1990*ft 150*ft];

%Define fracture geometry
NumFracs=1;
Frac_Spacing=1990*ft;
Frac_halfLength=350*ft;
Frac_height=150*ft; %Thickness of reservoir
Frac_StartXY=[physdim(1)/2 physdim(2)/2-Frac_halfLength];

[fl,xy_wells]=createMultiStageFracs(NumFracs,Frac_Spacing,...
    Frac_halfLength,Frac_StartXY);

%% Define geometric quantitites
% Create explicit fracture grid with Log LGR

%%{ 
%EDFM + LGR
[G,fl] = ExplicitFracGridNF(physdim,...
    NumFracs,Frac_Spacing,Frac_halfLength,Frac_StartXY,...
    'NX_FracRefine',250,'NX_OutRefine',1,...
    'NY_OutRefine',10,...
    'FracCellSize',0.01*ft,...
    'FracCellSize_Y',0.01*ft,...
    'NumNFs',3,'NY_Refine',10,'NY_LogRefine',true,...
    'NF_Spacing',2*Frac_halfLength/3,...
    'NF_Length',200*ft,...
    'NF_RepeatPatternSpace',215*ft,...
    'NF_StartXY',[Frac_StartXY(1)-307*ft Frac_StartXY(2)]);
%%}

%{ 
%Plot coarse for Manuscript
[G,fl] = ExplicitFracGridNF(physdim,...
    NumFracs,Frac_Spacing,Frac_halfLength,Frac_StartXY,...
    'NX_FracRefine',10,'NX_OutRefine',1,...
    'NY_OutRefine',5,...
    'FracCellSize',0.01*ft,...
    'FracCellSize_Y',70*ft,...
    'NumNFs',3,'NY_Refine',2,'NY_LogRefine',false,...
    'NF_Spacing',2*Frac_halfLength/3,...
    'NF_Length',200*ft,...
    'NF_RepeatPatternSpace',215*ft,...
    'NF_StartXY',[Frac_StartXY(1)-307*ft Frac_StartXY(2)]);
%}

G = computeGeometry(G);

[NX,NY]=deal(G.cartDims(1),G.cartDims(2));


plotFracGeo(physdim,fl(:,:),xy_wells,'FigSize',600,'Title','EDFM Grid');
%Plot Grid
plotGrid(G), view(2), axis equal tight;

%% Define rock properties
[poro_rock,poro_frac]=deal(0.07,1.0);
[perm_rock,perm_frac,perm_NF]=deal(0.0005*milli*darcy,1000*darcy,0.5*darcy);
gravity reset off;

cellInx = sub2ind(G.cartDims, G.FracCell.I, G.FracCell.J);
perm=repmat(perm_rock,NX,NY);
poro=repmat(poro_rock,NX,NY);

%Hydraulic Fracture
perm(cellInx)=perm_frac;
poro(cellInx)=poro_frac;

%Natural Fracture
perm(cellInx(G.FracCell.NFStartIdx:end))=perm_NF;
poro(cellInx(G.FracCell.NFStartIdx:end))=poro_frac;


rock = makeRock(G, perm(:), poro(:));

%Plot perm/poro field
%plotCellData (G , convertTo ( rock.perm , milli * darcy ));
%colorbar ('horiz'); view (2); axis equal tight ;
%plotCellData (G , rock.poro);
%colorbar ('horiz'); view (2); axis equal tight ; 

%% Black-oil shale gas fluid properties
[fluid]=setShaleGasFluid_Case1(G,rock);

%% Define shale gas flow model
model = WaterModelG(G,rock,fluid);

%% Assume constant BHP horizontal well
IJ_wells = markCellbyXY(xy_wells,G);
cellInx = sub2ind(G.cartDims, IJ_wells(:,1), IJ_wells(:,2));
W = addWell([], G, rock, cellInx,'Dir', 'x','Radius', 0.25*ft, ...
        'Type', 'bhp', 'Val', 500*psia,'Comp_i',1);

%time step has to be setup with wells
M = csvread('CMG_timestep2.csv',1);
dt_list=M(:,1)*day;
time_list=cumsum(convertTo(dt_list,day));

schedule = simpleSchedule(dt_list, 'W', W);

%% Impose initial pressure equilibrium
p0=5000*psia;
state  = initResSol(G, p0, 0);%0-single phase model

%% Plot well and permeability
% Since the well is inside the reservoir, we remove a section around the
% well so that we can see the well path
%%{
clf;
show = true([G.cells.num, 1]);
show(cellInx) = false;% Hide well cell
plotCellData (G , convertTo(rock.perm,milli*darcy),show, 'EdgeColor', 'k');
%plotCellData(G, convertTo(p_init, barsa), show, 'EdgeColor', 'k');
colorbar ('horiz'); view (2); axis equal tight;
%%}
%% Run simulations
[ws, states, report] = simulateScheduleAD(state, model, schedule);

if isfield(fluid,'mG_ad')
    data_file='CMG_PRO_Langmuir.csv';
else
    data_file='CMG_PRO_base.csv';
end

%plotWellSols({ws},dt_list, 'field','qWs');
PlotEDFMGasRate(time_list,ws, ...
    'Reference_data',data_file,...
    'YUnit', ft^3/day,...
    'XUnit', day,...
    'Xlim',[1e-4 1e4],...
    'CumPlot',1,...
    'LogLog',1);
PlotEDFMPresSurf(fl,G,states,numel(time_list),'ColorLim',[3.5 35])