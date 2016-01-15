%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DESCRIPTION: This script compares different scenarios that are simulated with
% AquaCrop-Hydro. It runs each scenario and compares crop yield, soil water balance and river
% discharge (cumulative volumes) for every scenario
%
% TO DO before running the script: 
%   1. Run AquaCrop simulations for all land units in the catchment for
%      each scenario
%   2. Ensure that all AquaCrop output files are numbered with format "01", "02",
%      "03", "10","20" according to the landunit number
%   3. Ensure that all AquaCrop ouput files are organized in subfolders
%      with the name of the scenario
%   4. Prepare all required input files for this script
%   5. Add the paths where the DateCalc.m en ClimSubtotal.m file are
%   located to the searchpath of matlab (see section 1)
%   (6. Make sure that the first scenario (specified in Scenario.txt) is
%   the baseline scenario )
%
% Author: Hanne Van Gaelen
% Last updated: 14/01/2016
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% ------------------------------------------------------------------------
% 1. DEFINE DATA PATHS (BY USER)                                                    
%--------------------------------------------------------------------------      

% Add the paths where the DateCalc.m en ClimSubtotal.m file are
%   located to the searchpath of matlab
    newpath1='C:\DATA_HanneV\~Onderzoek\DEEL 2 - Ecohydro model\DEEL IIB  -VHM-AC\Github\AquaCrop_Extra';
    newpath2='C:\DATA_HanneV\~Onderzoek\DEEL 2 - Ecohydro model\DEEL IIB  -VHM-AC\Github\Climate_Processing';
    path(path,newpath1) %adds the newpath folder to the bottom of the search path. 
    path(path,newpath2)

    clear newpath1 newpath2
    
% specify in which path all AquaCrop simulation output files are stored for
% all scenarios (each scenario in different subfolder). Make sure also to
% store the AquaCrop climate files (Temp, ET0, rainfall)

     DatapathAC=uigetdir('C:\','Select directory of scenario subfloders with AquaCrop output files for all landunits');     
     
% specify in which path all inputs for AquaCrop-Hydro are stored including 
%    a) additional information on AquaCrop simulations of each landunits (SimInfo.txt)
%    b) the parameters for the hydrological model (Parameters.txt)
%    c) the maximum root depth for every landunit and sim run (Zrx.txt)
%    d) the soil parameters of each soil type present (SoilPar.txt)

     DatapathACHinput = uigetdir('C:\','Select directory with all input files for AquaCrop-Hydro ');
     
% specify in which path all output should be stored including 
%   a) Flow values (baseflow, interflow, overland flow, total flow) as
%   simulated by AquaCrop-Hydro
%   b) Catchment water balance values as simulated by AquaCrop-Hydro

     DatapathACHOutput=uigetdir('C:\','Select directory with scenario subfloders to store AquaCrop-Hydro output (flows and water balance values)');        

% specify in which path all information on the scenario comparison is stored including  
 %    a) information on the different scenarios (Scenario.txt)    
     
     DatapathScenIn = uigetdir('C:\','Select directory with all input information on the scenario comparison ');     

% specify in which path all output of scenario comparison (figure and workspace variables) should be stored   
     
     DatapathScenOut = uigetdir('C:\','Select directory to store scenario comparison output (figures and variables) ');     

% specify in which path all inputs for date calculations are stored (each scenario in different subfolder) including *Temp.Txt and *PrChar.txt) 

     DatapathDate= uigetdir('C:\','Select directory of scenario subfloders with all input files for date calculations');

% specify the AquaCrop mode that was used (1= normal AquaCrop, 2= plugin version)
     ACMode=inputdlg('Did you use AquaCrop normal (1) or stand-alone plugin version (2)?','AquaCrop Mode');
     ACMode=cell2mat(ACMode);
     ACMode=str2double(ACMode);

     if ACMode==1 || ACMode==2
         %continue
     else
         error('invalid AquaCrop mode selected');
     end
     
% specify the category that you want to group scenarios in
     GroupCat=inputdlg('Do you want to group scenario analysis per RCP scenario (1), climate model (2) or management category (3)?','Grouping category');
     GroupCat=cell2mat(GroupCat);
     GroupCat=str2double(GroupCat);

     if GroupCat==1 || GroupCat==2 || GroupCat==3
         %continue
     else
         error('invalid grouping category selected - it can only be 1-2-3');
     end 
     
%% ------------------------------------------------------------------------
% 2. LOAD EXTRA INFORMATION ON SIIMULATIONS AND LANDUNITS                                                  
%--------------------------------------------------------------------------        
        
% 2.1 Load information on different landunits
%-------------------------------------------------------------------------    
 
 % Select file with info on simulations
    name='SimInfo.txt';
    file = fullfile(DatapathACHinput, name);        
    A= importdata(file); 
    clear name file
    
 % Read all data of each simulation unit
    SimName=A.textdata(:,1);    % Name 
    SimNr=A.data(:,2);          % Numeric code of this simulation unit 
    SimType=A.data(:,3);        % Type of this simulation unit (1= other landuse (e.g forest, water, urban), 2= agricultural landuse, 999= no simulation)
    Clim=A.textdata(:,2);       % Climate 
    Soil=A.textdata(:,3);       % Soil type
    Crop=A.textdata(:,4);       % Crop type grown in main season
    CropAfter=A.textdata(:,5);  % Crop type grown after main season crop
    CropRot=A.textdata(:,6);    % Crop rotation (= main crop + after crop)
    SimArea=A.data(:,1);        % Relative area of this simulation unit in the catchment
    [nlu,~]=size(SimType(SimType(:,1)<900));   % real land units
    clear A

% 2.2 Load information on different scenarios
%-------------------------------------------------------------------------   
    name='Scenario.txt';
    file = fullfile(DatapathScenIn, name);        
    A= importdata(file); 
    clear name file   
    
    scnumb=A.data(:,1).'; 
    nsc=length(scnumb);
    ScenarioName=A.textdata(:,1).';
    ClimModel=A.textdata(:,2).';
    RCP=A.textdata(:,3).';
    Manag=A.textdata(:,4).';
    StartDate=datetime((A.data(:,2).'),'ConvertFrom','excel');
    EndDate=datetime((A.data(:,3).'),'ConvertFrom','excel');
    nTime=daysact(datenum(StartDate(1,1)), datenum(EndDate(1,1)))+1;
    clear A 
    
% 2.3 Create groups and labels for vizualization 
%-------------------------------------------------------------------------     

    if GroupCat==1 % grouping per RCP
        groupnames=unique(RCP(1,2:nsc)); %baseline excluded
        groupnames2=unique(RCP); % baseline not excluded
        ngroup=length(groupnames);
        ngroup2=length(groupnames2);   
        groupmat=RCP;
    elseif GroupCat==2 % grouping per climate model
        groupnames=unique(ClimModel(1,2:nsc));
        groupnames2=unique(ClimModel);
        ngroup=length(groupnames) ;
        ngroup2=length(groupnames2);   
        groupmat=ClimModel;
    elseif GroupCat==3 % grouping per management scenario
        groupnames=unique(Manag(1,2:nsc));
        groupnames2=unique(Manag);
        ngroup=length(groupnames);  
        ngroup2=length(groupnames2);   
        groupmat=Manag;
    else
        error('grouping category is not well defined');
    end
    
    linesstructall={'-','-','--',':','.-'}; % format of potential groups
    colorstructall={'[0 0 0]','[0.6 0.6 0.6]','[0.6 0.6 0.6]','[0.3 0.3 0.3]','[0.3 0.3 0.3]'};
    linewstructall={1.5,0.5,0.5,0.5,0.5};

    linesstruct=cell(nsc,1); % initialize
    colorstruct=cell(nsc,1);
    linewstruct=cell(nsc,1);

    for g=1:ngroup2 % format of actual groups
        index=strcmp(groupmat,groupnames2(1,g));
        linesstruct(index==1,1)=linesstructall(1,g);
        colorstruct(index==1,1)=colorstructall(1,g);
        linewstruct(index==1,1)=linewstructall(1,g);
    end
    
    
%% -----------------------------------------------------------------------
% 3. RUN AQUACROP-HYDRO FOR ALL SCENARIOS & SAVE OUTPUT OF EACH SCENARIO
%-------------------------------------------------------------------------            

%3.1 initialize variables
%-------------------------------------------------------------------------
    %time variables
    Day=NaN(nTime,nsc);    % Day number
    Month=NaN(nTime,nsc);  % Month number
    Year=NaN(nTime,nsc);   % Year number
    
    %climate variables
    Tmin=NaN(nTime,nsc); % minimum temperature (�C)
    Tmax=NaN(nTime,nsc); % maximum temperature (�C)
    Rain=NaN(nTime,nsc); % rainfall (mm)
    ETo=NaN(nTime,nsc); % reference evapotranspiration (mm)

    %catchment-scale results
    TrCatch=NaN(nTime,nsc);     % Crop transpiration (actual) (mm)
    TrxCatch=NaN(nTime,nsc);    % Potential (maximum) crop transpiration (mm)
    ECatch=NaN(nTime,nsc);      % Evaporation(actual)(mm)
    ExCatch=NaN(nTime,nsc);     % Potential (maximum) evaporation(mm)
    ETaCatch=NaN(nTime,nsc);    % Actual evapotranspiration(mm)
    ETxCatch=NaN(nTime,nsc);    % Potential (maximum) evapotranspiration(mm)
    ROCatch=NaN(nTime,nsc);     % Runoff(mm)
    DPCatch=NaN(nTime,nsc);     % Deep percolation(mm)
    CRCatch=NaN(nTime,nsc);     % Capilary rise(mm)
    BundWatCatch=NaN(nTime,nsc); % Water between bunds (mm)
    Wr2Catch=NaN(nTime,nsc);   % Soil water content in 2 m soil depth (mm)
    CCCatch=NaN(nTime,nsc);    % Canopy Cover (%)

   % AquaCrop results per simulation unit 
    Tr=cell(2,nsc) ;    % Crop transpiration(actual)(mm)
    Trx=cell(2,nsc) ;   % Potential (maximum) crop transpiration(mm)
    E=cell(2,nsc) ;     % Evaporation (actual)(mm)
    Ex=cell(2,nsc) ;    % Potential (maximum) evaporation(mm)
    ETa=cell(2,nsc) ;   % Actual evapotranspiration(mm)
    ETx=cell(2,nsc) ;   % Potential (maximum) evapotranspiration(mm)
    RO=cell(2,nsc) ;    % Runoff(mm)
    DP=cell(2,nsc) ;  % Deep percolation(mm)
    CR=cell(2,nsc) ;    % Capilary rise(mm)
    BundWat=cell(2,nsc) ; % Water between bunds (mm)
    Wr2=cell(2,nsc) ; % Soil water content in 2 m soil depth (mm)
    CC=cell(2,nsc) ;   % Canopy Cover (%)
    B=cell(2,nsc) ;    % Dry aboveground biomass during growing season (ton/ha)
    GDD=cell(2,nsc);
   
   % Crop results for main season (average over catchment)
     Prod=cell(2,nsc);  % crop production variabiles for main season crops
                        % for each scenario and each crop there is a matrix with 
                            % Bfinact=Actual simulated dry aboveground biomass at maturity (ton/ha)
                            % Bfinpot= Potential simulated biomass at maturity if no stresses(ton/ha)
                            % Bfinrel= Bfinact/Bfinpot (%)
                            % Yact= Actual simulated final yield at maturity (ton/ha)  
                            % HIact= Actual simulated Harvest index at maturity (%) as affected by stresses   
                            % LGPact=  Actual simulated length of growing period (days) as affected by early senescence

   % the catchment hydrology results   
    Q_MBF=NaN(nTime,nsc);
    Q_MIF=NaN(nTime,nsc);
    Q_MOF=NaN(nTime,nsc);      
    Q_MTF=NaN(nTime,nsc);

  % Add headers to matrices 
    Tr(1,1:nsc)= ScenarioName(1,1:nsc);  
    Trx(1,1:nsc)= ScenarioName(1,1:nsc);  
    E(1,1:nsc)= ScenarioName(1,1:nsc);  
    Ex(1,1:nsc)= ScenarioName(1,1:nsc);  
    ETa(1,1:nsc)=  ScenarioName(1,1:nsc);  
    ETx(1,1:nsc)=ScenarioName(1,1:nsc);   
    RO(1,1:nsc)= ScenarioName(1,1:nsc);  
    DP(1,1:nsc)=ScenarioName(1,1:nsc);         
    CR(1,1:nsc)=  ScenarioName(1,1:nsc);  
    BundWat(1,1:nsc)=ScenarioName(1,1:nsc);   
    Wr2(1,1:nsc)=   ScenarioName(1,1:nsc);   
    CC(1,1:nsc)=  ScenarioName(1,1:nsc);    
    B(1,1:nsc)= ScenarioName(1,1:nsc);  
    Prod(1,1:nsc)= ScenarioName(1,1:nsc);
    GDD(1,1:nsc)=ScenarioName(1,1:nsc);

%3.2 Run ACHydro and save output
%-------------------------------------------------------------------------
    
for sc=1:nsc %loop trough all scenarios
% show progress
disp(['Now running scenario ',num2str(sc),' of  ',num2str(nsc)]);
 
% Extract scenario name
Name=ScenarioName{1,sc};

% Datapaths for this scenario
  DatapathACSC=fullfile(DatapathAC,Name);
  DatapathInputSC=DatapathACHinput;                % input is the same for all scenarios   
  DatapathOutputSC=fullfile(DatapathACHOutput,Name);  

% Check if AquaCrop results for this scenario can be found  
    
    if exist(DatapathACSC) == 7
        %continue as the AquaCrop results for a scneario with this name
        %can be found
    else
        error(['The AquaCrop results for scenario ',num2str(sc),' with scenarioname ',Name,' could not be found'])
    end    
    
% Run AquaCrop-Hydro for this scenario
[Q_MBFsc,Q_MIFsc,Q_MOFsc,Q_MTFsc,area,f,Wrmin,Wrmax,pbf,SoilPar,SimACOutput,CatchACOutput,CropCatchACOutput,Par]=AquaCropHydro(DatapathACSC, DatapathInputSC,ACMode);

% extract output for this scenario       
        
        % Save time variables        
        Day(:,sc)=CatchACOutput(:,13);    % Day number
        Month(:,sc)=CatchACOutput(:,14);  % Month number
        Year(:,sc)=CatchACOutput(:,15);   % Year number
        Date(:,sc)=datetime(Year(:,sc),Month(:,sc),Day(:,sc)); % Date 
        
        % Extract climate variables 
        Tempstr=ReadACTempInput(DatapathACSC);
        Tmin(:,sc)=Tempstr{2,1}(:,1);
        Tmax(:,sc)=Tempstr{2,1}(:,2);
        Rainstr=ReadACPluInput(DatapathACSC);
        Rain(:,sc)=Rainstr{2,1};
        ETostr=ReadACEToInput(DatapathACSC);
        ETo(:,sc)=ETostr{2,1};
        
        %Check number of timesteps
        nt=length(CatchACOutput(:,1));   % Number of timesteps
        if nt==nTime 
         %continue and use nTime as timemarker
        else
         error('number of simulated days does not match number of days in specified baseline simulation period');
        end
               
        % Save catchment-scale AquaCrop results
        TrCatch(1:nTime,sc)=CatchACOutput(1:nTime,1);     % Crop transpiration (actual) (mm)
        TrxCatch(1:nTime,sc)=CatchACOutput(1:nTime,2);    % Potential (maximum) crop transpiration (mm)
        ECatch(1:nTime,sc)=CatchACOutput(1:nTime,3);      % Evaporation(actual)(mm)
        ExCatch(1:nTime,sc)=CatchACOutput(1:nTime,4);     % Potential (maximum) evaporation(mm)
        ETaCatch(1:nTime,sc)=CatchACOutput(1:nTime,5);    % Actual evapotranspiration(mm)
        ETxCatch(1:nTime,sc)=CatchACOutput(1:nTime,6);    % Potential (maximum) evapotranspiration(mm)
        ROCatch(1:nTime,sc)=CatchACOutput(1:nTime,7);     % Runoff(mm)
        DPCatch(1:nTime,sc)=CatchACOutput(1:nTime,8);     % Deep percolation(mm)
        CRCatch(1:nTime,sc)=CatchACOutput(1:nTime,9);     % Capilary rise(mm)
        BundWatCatch(1:nTime,sc)=CatchACOutput(1:nTime,10); % Water between bunds (mm)
        Wr2Catch(1:nTime,sc)=CatchACOutput(1:nTime,11);   % Soil water content in 2 m soil depth (mm)
        CCCatch(1:nTime,sc)=CatchACOutput(1:nTime,12);    % Canopy Cover (%)
                
       % Save original AquaCrop results per simulation unit 
        Tr{2,sc}=SimACOutput{1,1};    % Crop transpiration(actual)(mm)
        Trx{2,sc}=SimACOutput{1,2};   % Potential (maximum) crop transpiration(mm)
        E{2,sc}=SimACOutput{1,3};     % Evaporation (actual)(mm)
        Ex{2,sc}=SimACOutput{1,4};    % Potential (maximum) evaporation(mm)
        ETa{2,sc}=SimACOutput{1,5};   % Actual evapotranspiration(mm)
        ETx{2,sc}=SimACOutput{1,6};   % Potential (maximum) evapotranspiration(mm)
        RO{2,sc}=SimACOutput{1,7};    % Runoff(mm)
        DP{2,sc}=SimACOutput{1,8};    % Deep percolation(mm)
        CR{2,sc}=SimACOutput{1,9};    % Capilary rise(mm)
        BundWat{2,sc}=SimACOutput{1,10}; % Water between bunds (mm)
        Wr2{2,sc}=SimACOutput{1,11};  % Soil water content in 2 m soil depth (mm)
        CC{2,sc}=SimACOutput{1,12};   % Canopy Cover (%)
        B{2,sc}=SimACOutput{1,13};    % Dry aboveground biomass during growing season (ton/ha)
        GDD{2,sc}=SimACOutput{1,19};    % Dry aboveground biomass during growing season (ton/ha)
        
      % Save crop production results for main season   
        Prod{2,sc}=CropCatchACOutput(1:2,:); 
  
      % Save the catchment hydrology results   
        Q_MBF(1:nTime,sc)=Q_MBFsc(1:nTime,1);
        Q_MIF(1:nTime,sc)=Q_MIFsc(1:nTime,1);
        Q_MOF(1:nTime,sc)=Q_MOFsc(1:nTime,1);      
        Q_MTF(1:nTime,sc)=Q_MTFsc(1:nTime,1);

 
% write output for this scenario to excel      
      % Combine output in matrix if necessary
        HeadersFlow={'Date','Baseflow','Interflow','Overland flow', 'Total flow'};
        FlowOutput=[exceltime(Date(1:nTime,1)),Q_MBFsc(1:nTime,1),Q_MIFsc(1:nTime,1),Q_MOFsc(1:nTime,1),Q_MTFsc(1:nTime,1)];

        HeadersWabalCatch={'Date','Tr','Trx','E','Ex','ETa','ETx','RO','DP','CR','BundWat','Wr2'};

       % Write output to one excel tabsheet
        xlname='FlowSimResults.xlsx';
        filename = fullfile(DatapathOutputSC,xlname);
        xlswrite(filename,HeadersFlow,'SimFlow','A1');
        xlswrite(filename,FlowOutput,'SimFlow','A2');
    
        xlname='WabalSimResults.xlsx';
        filename = fullfile(DatapathOutputSC,xlname);
        xlswrite(filename,HeadersWabalCatch,'SimWabal','A1');
        xlswrite(filename,exceltime(Date(1:nTime,1)),'SimWabal','A2');
        xlswrite(filename,CatchACOutput(1:nTime,1:11),'SimWabal','B2'); 
        
        
clear SimACOutput CatchOutput FlowOutput WabalCatchOutput DatapathOutputSC DatapathInputSC   
clear Q_MTFsc Q_MOFsc Q_MIFsc Q_MBFsc
end

clear sc


% 3.3 Reorganize production variables per crop
%-------------------------------------------------------------------------
% Put yield, WPET, DSI en TS in one structure 

Cropnames= Prod{2,1}(1,:);
[~,ncrop]=size(Cropnames);

Yact(1,1:ncrop)=Cropnames(1,1:ncrop);
DSI(1,1:ncrop)=Cropnames(1,1:ncrop);
WP(1,1:ncrop)=Cropnames(1,1:ncrop);
TSI(1,1:ncrop)=Cropnames(1,1:ncrop);
LGPact(1,1:ncrop)=Cropnames(1,1:ncrop);

subsetY=[];
subsetDSI=[];
subsetWP=[];
subsetTS=[];
subsetLGP=[];

for c=1:ncrop % loop trough each crop
    for sc=1:nsc %loop trough each scenario
        addcolumn= Prod{2,sc}{2,c}(:,4);
        length(addcolumn);
        subsetY(1:length(addcolumn),end+1)=addcolumn;
        subsetY(length(addcolumn)+1:end,end)=NaN;
        clear addcolumn
        
        addcolumn= Prod{2,sc}{2,c}(:,8);
        length(addcolumn);
        subsetDSI(1:length(addcolumn),end+1)=addcolumn;
        subsetDSI(length(addcolumn)+1:end,end)=NaN;
        clear addcolumn
        
        addcolumn= Prod{2,sc}{2,c}(:,9);
        length(addcolumn);
        subsetWP(1:length(addcolumn),end+1)=addcolumn;
        subsetWP(length(addcolumn)+1:end,end)=NaN;
        clear addcolumn
        
        addcolumn= Prod{2,sc}{2,c}(:,10);
        length(addcolumn);
        subsetTS(1:length(addcolumn),end+1)=addcolumn;
        subsetTS(length(addcolumn)+1:end,end)=NaN;
        clear addcolumn
        
        addcolumn= Prod{2,sc}{2,c}(:,6);
        length(addcolumn);
        subsetLGP(1:length(addcolumn),end+1)=addcolumn;
        subsetLGP(length(addcolumn)+1:end,end)=NaN;
        clear addcolumn
    end
    Yact{2,c}=subsetY;
    DSI{2,c}=subsetDSI;
    WP{2,c}=subsetWP;
    TSI{2,c}=subsetTS;
    LGPact{2,c}=subsetLGP;  
    
    subsetY=[];
    subsetDSI=[];
    subsetWP=[];
    subsetTS=[];
    subsetLGP=[];
end

% Define index of crops you want to show
maize=find(strcmp(Cropnames(1,1:ncrop),'Maize')==1);
wwheat=find(strcmp(Cropnames(1,1:ncrop),'WinterWheat')==1);
sugarbeet=find(strcmp(Cropnames(1,1:ncrop),'Sugarbeet')==1);
potato=find(strcmp(Cropnames(1,1:ncrop),'Potato')==1);
pea=find(strcmp(Cropnames(1,1:ncrop),'Pea')==1);


clear c sc Cropnames subsetY subsetDSI subsetWP subsetTS subsetLGP

% 3.4 Save workspace
%-------------------------------------------------------------------------
% save workspace variables so that you can skip this the first part of the
% code next time

filename=['workspace ',datestr(date)];
filename=fullfile(DatapathScenOut,filename);
save(filename)
clear filename 
 

%% -----------------------------------------------------------------------
% 4. YIELD IMPACT 
%------------------------------------------------------------------------

% 4.1 Calculate statistics
%-------------------------------------------------------------------------
% stats for each crop over different years 
    Yactstats(1,1:ncrop)=Yact(1,1:ncrop); 
    
    for c=1:ncrop
        Yactstats{2,c}(1,1:nsc)=mean(Yact{2,c}(:,1:nsc));
        Yactstats{2,c}(2,1:nsc)=median(Yact{2,c}(:,1:nsc));
        Yactstats{2,c}(3,1:nsc)=std(Yact{2,c}(:,1:nsc));
        Yactstats{2,c}(4,1:nsc)=min(Yact{2,c}(:,1:nsc));
        Yactstats{2,c}(5,1:nsc)=max(Yact{2,c}(:,1:nsc));
        Yactstats{2,c}(6,1:nsc)=Yactstats{2,c}(3,1:nsc)./Yactstats{2,c}(1,1:nsc);
    end
clear c

% Calculate changes of stats (change of avg, change of median)
    YactDeltastats(1,1:ncrop)=Yact(1,1:ncrop); 

    for c=1:ncrop
        for stat=1:2
        YactDeltastats{2,c}(stat,1:nsc)=(Yactstats{2,c}(stat,1:nsc)-Yactstats{2,c}(stat,1))./Yactstats{2,c}(stat,1);
        end
    end

clear c
   
% 4.2 Vizualize yield impact with boxplots
%-------------------------------------------------------------------------

f1=figure('name','Median yield changes');%(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(YactDeltastats{2,maize}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Median yield change (%)')
        axis([xlim, -30,30])
        set(gca,'box','off')
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(YactDeltastats{2,wwheat}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(YactDeltastats{2,potato}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(YactDeltastats{2,sugarbeet}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(YactDeltastats{2,pea}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(Yactstats{2,maize}(2,1))
        ylabel('Median historical yield (ton/ha)')
        axis([xlim , 0 ,15])
        title('Maize')
        set(gca,'XTickLabel',{' '})
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(Yactstats{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '})
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(Yactstats{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '})
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(Yactstats{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '})
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(Yactstats{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '})
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously

        clear sub h 
        
% 4.3 Analyse with focus on interannual variability as well
% -----------------------------------------------------------------------        

% Change of yield as compared to historical median for all years
    YallDelta(1,1:ncrop)=Yact(1,1:ncrop); 
    
    YallDelta{2,maize}=(Yact{2,maize}-Yactstats{2,maize}(2,1))./Yactstats{2,maize}(2,1);   
    YallDelta{2,wwheat}=(Yact{2,wwheat}-Yactstats{2,wwheat}(2,1))./Yactstats{2,wwheat}(2,1);   
    YallDelta{2,sugarbeet}=(Yact{2,sugarbeet}-Yactstats{2,sugarbeet}(2,1))./Yactstats{2,sugarbeet}(2,1);   
    YallDelta{2,potato}=(Yact{2,potato}-Yactstats{2,potato}(2,1))./Yactstats{2,potato}(2,1);   
    YallDelta{2,pea}=(Yact{2,pea}-Yactstats{2,pea}(2,1))./Yactstats{2,pea}(2,1);  
    
f2=figure('name','Median yield changes- GCM&year variation');% boxplot = variation over different GCMs & over 30 different year)   

    sub(1)=subplot(1,5,1,'fontsize',10);
    boxplot(YallDelta{2,maize}(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
    line(xlim,[0,0],'Color','k','LineStyle','--')
    ylabel('Annual yield from historical median (%)')
    title('maize')
    axis([xlim, -100,100])
    set(gca,'box','off')

    sub(2)=subplot(1,5,2,'fontsize',10);
    boxplot(YallDelta{2,wwheat}(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
    line(xlim,[0,0],'Color','k','LineStyle','--')
    title('winter wheat')
    set(gca,'box','off','YTick',[])

    sub(3)=subplot(1,5,3,'fontsize',10);
    boxplot(YallDelta{2,sugarbeet}(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
    line(xlim,[0,0],'Color','k','LineStyle','--')
    title('sugarbeet')
    set(gca,'box','off','YTick',[])

    sub(4)=subplot(1,5,4,'fontsize',10);
    boxplot(YallDelta{2,potato}(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
    line(xlim,[0,0],'Color','k','LineStyle','--')
    title('potato')
    set(gca,'box','off','YTick',[])

    sub(5)=subplot(1,5,5,'fontsize',10);
    boxplot(YallDelta{2,pea}(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
    line(xlim,[0,0],'Color','k','LineStyle','--')
    title('pea')
    set(gca,'box','off','YTick',[])
    
    linkaxes(sub,'y')   
  

% 4.4 Vizualize yield impact with cumulative distribution function
%-------------------------------------------------------------------------

% normality check 
[notnormalmaize,~]=NormalityCheck(Yact{2,maize},'lillie',0.05);
[notnormalwwheat,~]=NormalityCheck(Yact{2,wwheat},'lillie',0.05);
[notnormalsbeet,~]=NormalityCheck(Yact{2,sugarbeet},'lillie',0.05);
[notnormalpotato,~]=NormalityCheck(Yact{2,potato},'lillie',0.05);
[notnormalpea,~]=NormalityCheck(Yact{2,pea},'lillie',0.05);

if isempty(notnormalmaize)==1 && isempty(notnormalwwheat)==1 && isempty(notnormalsbeet)==1 && isempty(notnormalpotato)==1 && isempty(notnormalpea)==1
    disp('Yield values for all crops and all scenarios are normally distributed')
else
    if isempty(notnormalmaize)==0
    warning(['Maize yield is not normally distributed for scenarios: ',num2str(notnormalmaize.')])
    end
    
    if isempty(notnormalwwheat)==0
    warning(['Winter wheat yield is not normally distributed for scenarios: ',num2str(notnormalwwheat.')])
    end
    
    if isempty(notnormalsbeet)==0
    warning(['Sugar beet yield is not normally distributed for scenarios: ',num2str(notnormalsbeet.')])
    end
    
    if isempty(notnormalpotato)==0
    warning(['Potato yield is not normally distributed for scenarios: ',num2str(notnormalpotato.')])
    end
    
    if isempty(notnormalpea)==0
    warning(['Pea yield is not normally distributed for scenarios: ',num2str(notnormalpea.')])
    end
end


clear notnormalwwheat notnormalmaize notnormalpotato notnormalsbeet notnormalpea

% fit theoretical normal distributions
xrangemaize=0:0.5:max(Yact{2,maize}(:))+1.5;
xrangewwheat=0:0.5:max(Yact{2,wwheat}(:))+1.5;
xrangesbeet=0:0.5:max(Yact{2,sugarbeet}(:))+1.5;
xrangepotato=0:0.5:max(Yact{2,potato}(:))+1.5;
xrangepea=0:0.1:max(Yact{2,pea}(:))+1;

probabilitiesmaize=NaN(length(xrangemaize),nsc);
probabilitieswwheat=NaN(length(xrangewwheat),nsc);
probabilitiessbeet=NaN(length(xrangesbeet),nsc);
probabilitiespotato=NaN(length(xrangepotato),nsc);
probabilitiespea=NaN(length(xrangepea),nsc);

for sc=1:nsc
pdsc=fitdist(Yact{2,maize}(:,sc),'Normal');
probabilitiesmaize(:,sc)=cdf(pdsc,xrangemaize);

pdsc=fitdist(Yact{2,wwheat}(:,sc),'Normal');
probabilitieswwheat(:,sc)=cdf(pdsc,xrangewwheat);

pdsc=fitdist(Yact{2,sugarbeet}(:,sc),'Normal');
probabilitiessbeet(:,sc)=cdf(pdsc,xrangesbeet);

pdsc=fitdist(Yact{2,potato}(:,sc),'Normal');
probabilitiespotato(:,sc)=cdf(pdsc,xrangepotato);

pdsc=fitdist(Yact{2,pea}(:,sc),'Normal');
probabilitiespea(:,sc)=cdf(pdsc,xrangepea);
end

clear pdsc 

% vizualize

f3=figure('name','Seasonal yield theoretical CDF');
    subplot(3,2,1,'fontsize',10);
    P=plot(xrangemaize,probabilitiesmaize(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual yield (ton/ha)','fontsize',8);
    title('Maize')
    set(gca,'box','off')

    subplot(3,2,2,'fontsize',10);
    P=plot(xrangewwheat,probabilitieswwheat(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual yield (ton/ha)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    
    subplot(3,2,3,'fontsize',10);
    P=plot(xrangesbeet,probabilitiessbeet(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual yield (ton/ha)','fontsize',8);
    title('Sugarbeet')
    set(gca,'box','off')
    
    subplot(3,2,4,'fontsize',10);
    P=plot(xrangepotato,probabilitiespotato(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual yield (ton/ha)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    
    subplot(3,2,5,'fontsize',10);
    P=plot(xrangepea,probabilitiespea(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual yield (ton/ha)','fontsize',8);
    title('pea')
    set(gca,'box','off')

    
f4=figure('name','Seasonal yield emperical CDF');
    subplot(3,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Yact{2,maize}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Seasonal yield (ton/ha)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(3,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Yact{2,wwheat}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Seasonal yield (ton/ha)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(3,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Yact{2,sugarbeet}(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Seasonal yield (ton/ha)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(3,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Yact{2,potato}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Seasonal yield (ton/ha)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(3,2,5,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Yact{2,pea}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Seasonal yield (ton/ha)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off
    
clear xrangepotato xrangemaize xrangewwheat xrangesbeet xrangepea 


% 4.5 Save vizualization
%-------------------------------------------------------------------------
filename='Yield median changes - GCMboxplots';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)

filename='Yield empirical CDF ';
filename=fullfile(DatapathScenOut,filename);
savefig(f4,filename)

clear filename 

%% -----------------------------------------------------------------------
% 5. WPET IMPACT 
%------------------------------------------------------------------------

% 5.1 Calculate WPET statistics
%-------------------------------------------------------------------------
% stats for each crop over different years 

    WPstats(1,1:ncrop)=WP(1,1:ncrop); 
    
    for c=1:ncrop
        WPstats{2,c}(1,1:nsc)=mean(WP{2,c}(:,1:nsc));
        WPstats{2,c}(2,1:nsc)=median(WP{2,c}(:,1:nsc));
        WPstats{2,c}(3,1:nsc)=std(WP{2,c}(:,1:nsc));
        WPstats{2,c}(4,1:nsc)=min(WP{2,c}(:,1:nsc));
        WPstats{2,c}(5,1:nsc)=max(WP{2,c}(:,1:nsc));
    end
clear c

% Calculate changes of stats (change of avg, change of median)
    WPDeltastats(1,1:ncrop)=WP(1,1:ncrop); 

    for c=1:ncrop
        for stat=1:2
        WPDeltastats{2,c}(stat,1:nsc)=(WPstats{2,c}(stat,1:nsc)-WPstats{2,c}(stat,1));
        end
    end

clear c

% 5.2 Vizualize WPET impact with boxplots
%-------------------------------------------------------------------------

f1=figure('name','Median WPET changes');%(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(WPDeltastats{2,maize}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Median WPET change (%)')
        axis([xlim, -30,150])
        set(gca,'box','off')
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(WPDeltastats{2,wwheat}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(WPDeltastats{2,potato}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(WPDeltastats{2,sugarbeet}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(WPDeltastats{2,pea}(2,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(WPstats{2,maize}(2,1))
        ylabel('Median historical WP(%)')
        axis([xlim , 0 ,4])
        title('Maize')
        set(gca,'XTickLabel',{' '})
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(WPstats{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '})
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(WPstats{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '})
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(WPstats{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '})
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(WPstats{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '})
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously

        clear sub h 
        
% 5.3 Vizualize WPET with cumulative distribution function
%-------------------------------------------------------------------------
f2=figure('name','WP empirical CDF');
    subplot(3,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(WP{2,maize}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('WPET (kg/m�)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(3,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(WP{2,wwheat}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('WPET (kg/m�)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(3,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(WP{2,sugarbeet}(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('WPET (kg/m�)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(3,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(WP{2,potato}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('WPET (kg/m�)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(3,2,5,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(WP{2,pea}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('WPET (kg/m�)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off
    
% 5.4 save vizualization
%-------------------------------------------------------------------------
filename='WPET median changes - GCMboxplots';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)

filename='WPET empirical CDF ';
filename=fullfile(DatapathScenOut,filename);
savefig(f2,filename)

clear filename 
%% -----------------------------------------------------------------------
% 6. DROUGHT STRESS INDEX (DSI) and TEMPERATURE STRESS(TSI) IMPACT 
%------------------------------------------------------------------------

% 6.1 Calculate DSI en TSI statistics
%-------------------------------------------------------------------------
% stats for each crop over different years 
    DSIstats(1,1:ncrop)=DSI(1,1:ncrop); 
    TSIstats(1,1:ncrop)=TSI(1,1:ncrop);
    
    for c=1:ncrop
        DSIstats{2,c}(1,1:nsc)=mean(DSI{2,c}(:,1:nsc));
        DSIstats{2,c}(2,1:nsc)=median(DSI{2,c}(:,1:nsc));
        DSIstats{2,c}(3,1:nsc)=std(DSI{2,c}(:,1:nsc));
        DSIstats{2,c}(4,1:nsc)=min(DSI{2,c}(:,1:nsc));
        DSIstats{2,c}(5,1:nsc)=max(DSI{2,c}(:,1:nsc));
        DSIstats{2,c}(6,1:nsc)=prctile(DSI{2,c}(:,1:nsc),95);
        
        TSIstats{2,c}(1,1:nsc)=mean(TSI{2,c}(:,1:nsc));
        TSIstats{2,c}(2,1:nsc)=median(TSI{2,c}(:,1:nsc));
        TSIstats{2,c}(3,1:nsc)=std(TSI{2,c}(:,1:nsc));
        TSIstats{2,c}(4,1:nsc)=min(TSI{2,c}(:,1:nsc));
        TSIstats{2,c}(5,1:nsc)=max(TSI{2,c}(:,1:nsc));
        TSIstats{2,c}(6,1:nsc)=prctile(TSI{2,c}(:,1:nsc),95);
    end
clear c

% Calculate changes of stats (change of avg, change of median)
    DSIDeltastats(1,1:ncrop)=DSI(1,1:ncrop); 
    TSIDeltastats(1,1:ncrop)=TSI(1,1:ncrop); 
    
    for c=1:ncrop
        for stat=1:2
        DSIDeltastats{2,c}(stat,1:nsc)=(DSIstats{2,c}(stat,1:nsc)-DSIstats{2,c}(stat,1));
        TSIDeltastats{2,c}(stat,1:nsc)=(TSIstats{2,c}(stat,1:nsc)-TSIstats{2,c}(stat,1));
        end
    end

clear c stat


% 6.3 Vizualize DSI & TSI impact with boxplots
%-------------------------------------------------------------------------

f1=figure('name','Median DSI changes');%(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(DSIDeltastats{2,maize}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Median DSI change (%)')
        axis([xlim, -5,20])
        set(gca,'box','off')
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(DSIDeltastats{2,wwheat}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(DSIDeltastats{2,potato}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(DSIDeltastats{2,sugarbeet}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(DSIDeltastats{2,pea}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(DSIstats{2,maize}(2,1))
        ylabel('Median historical DSI(%)')
        axis([xlim , 0 ,20])
        title('Maize')
        set(gca,'XTickLabel',{' '})
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(DSIstats{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '})
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(DSIstats{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '})
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(DSIstats{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '})
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(DSIstats{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '})
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously

        clear sub h 
        
f2=figure('name','Median Temperature stress changes');%(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(TSIDeltastats{2,maize}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Median TSI change (%)')
        axis([xlim, -20,5])
        set(gca,'box','off')
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(TSIDeltastats{2,wwheat}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(TSIDeltastats{2,potato}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(TSIDeltastats{2,sugarbeet}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(TSIDeltastats{2,pea}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off')
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(TSIstats{2,maize}(2,1))
        ylabel('Median historical TSI(%)')
        axis([xlim , 0 ,40])
        title('Maize')
        set(gca,'XTickLabel',{' '})
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(TSIstats{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '})
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(TSIstats{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '})
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(TSIstats{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '})
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(TSIstats{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '})
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously

        clear sub h         
        
        
        
% 6.3 Vizualize DSI & TSI with cumulative distribution function
%-------------------------------------------------------------------------
f3=figure('name','DSI empirical CDF');
    subplot(5,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(DSI{2,maize}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Drought stress index (%)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(5,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(DSI{2,wwheat}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Drought stress index (%)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(5,2,5,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(DSI{2,sugarbeet}(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Drought stress index (%)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(5,2,7,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(DSI{2,potato}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Drought stress index (%)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(5,2,9,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(DSI{2,pea}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Drought stress index (%)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off
    
    subplot(5,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(TSI{2,maize}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Temperature stress index (%)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(5,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(TSI{2,wwheat}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Temperature stress index (%)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(5,2,6,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(TSI{2,sugarbeet}(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Temperature stress index (%)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(5,2,8,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(TSI{2,potato}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Temperature stress index (%)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(5,2,10,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(TSI{2,pea}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Temperature stress index (%)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off    
    
% 6.4 save vizualization
%-------------------------------------------------------------------------
filename='DSI median changes - GCMboxplots';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)

filename='TSI median changes - GCMboxplots';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)

filename='DSI_TSI empirical CDF ';
filename=fullfile(DatapathScenOut,filename);
savefig(f3,filename)

clear filename 
%% -----------------------------------------------------------------------
% 7. IMPACT ON LENGTH OF THE POTENTIAL LENGTH OF GROWING CYCLE 
%-------------------------------------------------------------------------
% Potential length of growing cycle = the length based purely on
% temperature and crop cycle requirements. If a crop dies of early due to
% water stress this is not taken into account


% 7.1 Calculate potential length of growing period & sowing/maturity dates
%-------------------------------------------------------------------------
LGPpotAll(1,1:nsc)=ScenarioName(1,1:nsc);
sowingAll(1,1:nsc)=ScenarioName(1,1:nsc);
maturityAll(1,1:nsc)=ScenarioName(1,1:nsc);

for sc=1:nsc
    DatapathDateSC=fullfile(DatapathDate,ScenarioName{1,sc});
    DatapathOutputSC=fullfile(DatapathACHOutput,ScenarioName{1,sc});
    RotationDateSC=CalcDate(DatapathDateSC,DatapathOutputSC,StartDate(1,sc),EndDate(1,sc)); 
    
    for lu=1:nlu
        if SimType(lu,1)==2
            nrun=length(RotationDateSC{1,lu}(:,3));
            r=(nrun-rem(nrun,2))/2;     
            SowingDateSC(1:r,lu)= RotationDateSC{1,lu}(2:2:nrun,3);   
            MaturityDateSC(1:r,lu)= RotationDateSC{1,lu}(2:2:nrun,4);
        else 
            % skip this landunit (not agriculture)
        end
    end
    
    LengthSC=(datenum(MaturityDateSC)-datenum(SowingDateSC))+1;
    
    LGPpotAll{2,sc}=LengthSC; % per scenario one matrix with cycle lengths per landunit
    sowingAll{2,sc}=SowingDateSC;
    maturityAll{2,sc}=MaturityDateSC;
end

clear sc lu SowingDateSC MaturityDateSC LengthSC RotationDateSC

% 7.2 Compose LGPpotential/sowing date  matrix per crop type
%--------------------------------------------------------------------------
Cropnames= Prod{2,1}(1,:);
[~,ncrop]=size(Cropnames);

LGPpot=cell(2,ncrop);% initialize
sowing=cell(2,ncrop);
LGPpot(1,1:ncrop)=Cropnames(1:1:ncrop); % write away crop name
sowing(1,1:ncrop)=Cropnames(1:1:ncrop); 
maturity(1,1:ncrop)=Cropnames(1:1:ncrop);

for c=1:ncrop% loop trough each crop 
     
    %search all projects with this crop
    index=find(strcmp(Crop(:,1),Cropnames(c))==1);
   
    for sc=1:nsc %loop trough al scenarios
        LGPpot{2,c}(:,sc)= LGPpotAll{2,sc}(:,index(1));% all landunits with same crop will have same LGPpot want same temp 
        sowing{2,c}(:,sc)= sowingAll{2,sc}(:,index(1));
        maturity{2,c}(:,sc)= maturityAll{2,sc}(:,index(1));
    end        
end

clear sc c 

% 7.3 Calculate LGP statistics (over different year)
%-------------------------------------------------------------------------
 LGPpotstats(1,1:ncrop)=LGPpot(1,1:ncrop); 
    
    for c=1:ncrop
        LGPpotstats{2,c}(1,1:nsc)=nanmean(LGPpot{2,c}(:,1:nsc));
        LGPpotstats{2,c}(2,1:nsc)=nanmedian(LGPpot{2,c}(:,1:nsc));
        LGPpotstats{2,c}(3,1:nsc)=nanstd(LGPpot{2,c}(:,1:nsc));
        LGPpotstats{2,c}(4,1:nsc)=min(LGPpot{2,c}(:,1:nsc));
        LGPpotstats{2,c}(5,1:nsc)=max(LGPpot{2,c}(:,1:nsc));
    end
clear c

% Calculate changes of stats (change of avg, change of median)
     LGPpotDeltastats(1,1:ncrop)=LGPpot(1,1:ncrop);

    for c=1:ncrop
        for stat=1:2
        LGPpotDeltastats{2,c}(stat,1:nsc)=(LGPpotstats{2,c}(stat,1:nsc)-LGPpotstats{2,c}(stat,1));
        end
    end

clear c stat

% 7.4 Vizualize potential length of growing period 
%------------------------------------------------------------------------- 

%search indices of crops you want to show
maize=find(strcmp(LGPpot(1,:),'Maize')==1);
wwheat=find(strcmp(LGPpot(1,:),'WinterWheat')==1);
sugarbeet=find(strcmp(LGPpot(1,:),'Sugarbeet')==1);
potato=find(strcmp(LGPpot(1,:),'Potato')==1);
pea=find(strcmp(LGPpot(1,:),'Pea')==1);

f1=figure('name','Median LGPpot changes'); %(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(LGPpotDeltastats{2,maize}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Change of growing cycle length (days)')
        axis([xlim, -50,10])
        set(gca,'box','off');
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(LGPpotDeltastats{2,wwheat}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(LGPpotDeltastats{2,potato}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(LGPpotDeltastats{2,sugarbeet}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(LGPpotDeltastats{2,pea}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(LGPpot{2,maize}(2,1))
        ylabel('Medain historical growing cycle length (days)')
        axis([xlim , 0 ,300])
        title('Maize')
        set(gca,'XTickLabel',{' '});
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(LGPpot{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '});
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(LGPpot{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '});
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(LGPpot{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '});
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(LGPpot{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '});
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously


f2=figure('name','LGPpot emperical CDF');
    subplot(3,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPpot{2,maize}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Potential LGP (days)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(3,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPpot{2,wwheat}(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Potential LGP (days)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(3,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPpot{2,sugarbeet}(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Potential LGP (days)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(3,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPpot{2,potato}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Potential LGP (days)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(3,2,5,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPpot{2,pea}(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Potential LGP (days)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off        
        
%save figure
filename='LGPpot median changes - GCMboxplot';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)
 
filename='LGPpot empirical CDF';
filename=fullfile(DatapathScenOut,filename);
savefig(f2,filename)

clear sub h  
%% -----------------------------------------------------------------------
% 8. IMPACT ON ACTUAL LENGTH OF GROWING CYCLE 
%-------------------------------------------------------------------------
% Actual length of growing cycle = the length based  on
% temperature and crop cycle requirements, as well as water stress which causes early senescence. 

% 8.1 Calculate statistics (over different year)
%-------------------------------------------------------------------------
 LGPactstats(1,1:ncrop)=LGPact(1,1:ncrop); 
    
    for c=1:ncrop
        LGPactstats{2,c}(1,1:nsc)=nanmean(LGPact{2,c}(:,1:nsc));
        LGPactstats{2,c}(2,1:nsc)=nanmedian(LGPact{2,c}(:,1:nsc));
        LGPactstats{2,c}(3,1:nsc)=nanstd(LGPact{2,c}(:,1:nsc));
        LGPactstats{2,c}(4,1:nsc)=min(LGPact{2,c}(:,1:nsc));
        LGPactstats{2,c}(5,1:nsc)=max(LGPact{2,c}(:,1:nsc));
    end
clear c

% Calculate changes of stats (change of avg, change of median)
     LGPactDeltastats(1,1:ncrop)=LGPact(1,1:ncrop);

    for c=1:ncrop
        for stat=1:2
        LGPactDeltastats{2,c}(stat,1:nsc)=(LGPactstats{2,c}(stat,1:nsc)-LGPactstats{2,c}(stat,1));
        end
    end

clear c

% 7.2 Vizualize actual length of growing period 
%------------------------------------------------------------------------- 

f1=figure('name','Median LGPact changes'); %(boxplot= variation over different GCMs) 
        sub(1)=subplot(2,5,1,'fontsize',10);
        boxplot(LGPactDeltastats{2,maize}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Change of growing cycle length (days)')
        axis([xlim, -50,10])
        set(gca,'box','off');
        title('Maize')
        
        sub(2)=subplot(2,5,2,'fontsize',10);
        boxplot(LGPactDeltastats{2,wwheat}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Winter Wheat')
        
        sub(3)=subplot(2,5,3,'fontsize',10);
        boxplot(LGPactDeltastats{2,potato}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Potato')
        
        sub(4)=subplot(2,5,4,'fontsize',10);
        boxplot(LGPactDeltastats{2,sugarbeet}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Sugarbeet')
        
        sub(5)=subplot(2,5,5,'fontsize',10);
        boxplot(LGPactDeltastats{2,pea}(2,2:nsc),groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
        line(xlim,[0,0],'Color','k','LineStyle','--')
        set(gca,'box','off');
        title('Peas')    

        linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
        
        h(1)=subplot(2,5,6,'fontsize',10);
        bar(LGPact{2,maize}(2,1))
        ylabel('Medain historical growing cycle length (days)')
        axis([xlim , 0 ,300])
        title('Maize')
        set(gca,'XTickLabel',{' '});
        
        h(2)=subplot(2,5,7,'fontsize',10);
        bar(LGPact{2,wwheat}(2,1))
        title('Winter Wheat')
        set(gca,'XTickLabel',{' '});
        
        h(3)=subplot(2,5,8,'fontsize',10);
        bar(LGPact{2,potato}(2,1))
        title('Potato')
        set(gca,'XTickLabel',{' '});
         
        h(4)=subplot(2,5,9,'fontsize',10);
        bar(LGPact{2,sugarbeet}(2,1))
        title('Sugarbeet')
        set(gca,'XTickLabel',{' '});
                
        h(5)=subplot(2,5,10,'fontsize',10);
        bar(LGPact{2,pea}(2,1))
        title('Peas')
        set(gca,'XTickLabel',{' '});
        
        linkaxes(h,'y')% link y axis of different plots (so that they change simultaneously

        clear sub h  

% 7.3 Vizualize LGPact with cumulative distribution function
%-------------------------------------------------------------------------
f2=figure('name','LGPact emperical CDF');
    subplot(3,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPact{2,maize}(:,i));
        hold on 
    end
    PP=cdfplot(LGPpot{2,maize}(:,1));
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    set(PP,{'Color'},{'k'},{'LineStyle'},{'--'},{'LineWidth'},{1.5})
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Actual LGP (days)','fontsize',8);
    title('Maize')
    set(gca,'box','off')
    grid off

    subplot(3,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPact{2,wwheat}(:,i));
        hold on 
    end
    PP=cdfplot(LGPpot{2,wwheat}(:,1));
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    set(PP,{'Color'},{'k'},{'LineStyle'},{'--'},{'LineWidth'},{1.5})
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Actual LGP (days)','fontsize',8);
    title('Winter Wheat')
    set(gca,'box','off') 
    grid off
    
    subplot(3,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPact{2,sugarbeet}(:,i));
        hold on 
    end
    PP=cdfplot(LGPpot{2,sugarbeet}(:,1));
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    set(PP,{'Color'},{'k'},{'LineStyle'},{'--'},{'LineWidth'},{1.5})
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Actual LGP (days)','fontsize',8);
    title('Sugar beet')
    set(gca,'box','off')
    grid off
    
    subplot(3,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPact{2,potato}(:,i));
        hold on 
    end    
    PP=cdfplot(LGPpot{2,potato}(:,1));
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    set(PP,{'Color'},{'k'},{'LineStyle'},{'--'},{'LineWidth'},{1.5})
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Actual LGP (days)','fontsize',8);
    title('Potato')
    set(gca,'box','off')
    grid off

    subplot(3,2,5,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(LGPact{2,pea}(:,i));
        hold on 
    end    
    PP=cdfplot(LGPpot{2,pea}(:,1));
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    set(PP,{'Color'},{'k'},{'LineStyle'},{'--'},{'LineWidth'},{1.5})
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Actual LGP (days)','fontsize',8);
    title('Pea')
    set(gca,'box','off')
    grid off   
              
% 7.5 Save vizualizations
%-------------------------------------------------------------------------
filename='LGPact median changes - gcmboxplot';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)
 
filename='LGPact empirical CDF';
filename=fullfile(DatapathScenOut,filename);
savefig(f2,filename)



%% -----------------------------------------------------------------------
% 8. TOTAL DISCHARGE IMPACT 
%------------------------------------------------------------------------

% 8.1 aggregation of results (subtotals and cumulative) 
% ----------------------------------------------------------------------- 

% cumulative over days
Q_MTFcum=cumsum(Q_MTF); 
Q_MBFcum=cumsum(Q_MBF); 
Q_MIFcum=cumsum(Q_MIF); 
Q_MOFcum=cumsum(Q_MOF); 

% subtotals
[Q_MTFyear,Q_MTFmonth,~,Q_MTFseason,Q_MTFymonth,~,Q_MTFyseason]=ClimSubtotal(Date(:,1),Q_MTF*f/area,'sum');
[Q_MBFyear,Q_MBFmonth,~,Q_MBFseason,Q_MBFymonth,~,Q_MBFyseason]=ClimSubtotal(Date(:,1),Q_MBF*f/area,'sum');
[Q_MIFyear,Q_MIFmonth,~,Q_MIFseason,Q_MIFymonth,~,Q_MIFyseason]=ClimSubtotal(Date(:,1),Q_MIF*f/area,'sum');
[Q_MOFyear,Q_MOFmonth,~,Q_MOFseason,Q_MOFymonth,~,Q_MOFyseason]=ClimSubtotal(Date(:,1),Q_MOF*f/area,'sum');


% 8.2 put data in matrix (not structure)
% ----------------------------------------------------------------------- 

    nyear=year(EndDate(1,1))-year(StartDate(1,1))+1;
    Q_MTFyear2=NaN(nyear,nsc);
    Q_MBFyear2=NaN(nyear,nsc);
    Q_MIFyear2=NaN(nyear,nsc);
    Q_MOFyear2=NaN(nyear,nsc);

    for sc=1:nsc
    Q_MTFyear2(:,sc)=Q_MTFyear{1,sc}(:,2);
    Q_MBFyear2(:,sc)=Q_MBFyear{1,sc}(:,2);
    Q_MIFyear2(:,sc)=Q_MIFyear{1,sc}(:,2);
    Q_MOFyear2(:,sc)=Q_MOFyear{1,sc}(:,2);
    end
    
% 8.3 Analyse with focus on variation between GCMs
% ----------------------------------------------------------------------- 
% stats per GCM over different years 
    Q_MTFyearstats=NaN(5,nsc);
    Q_MBFyearstats=NaN(5,nsc);
    Q_MIFyearstats=NaN(5,nsc);        
    Q_MOFyearstats=NaN(5,nsc);
    
    Q_MTFyearstats(1,1:nsc)=mean(Q_MTFyear2(:,1:nsc));
    Q_MTFyearstats(2,1:nsc)=median(Q_MTFyear2(:,1:nsc));
    Q_MTFyearstats(3,1:nsc)=std(Q_MTFyear2(:,1:nsc));
    Q_MTFyearstats(4,1:nsc)=min(Q_MTFyear2(:,1:nsc));
    Q_MTFyearstats(5,1:nsc)=max(Q_MTFyear2(:,1:nsc));
    
    Q_MBFyearstats(1,1:nsc)=mean(Q_MBFyear2(:,1:nsc));
    Q_MBFyearstats(2,1:nsc)=median(Q_MBFyear2(:,1:nsc));
    Q_MBFyearstats(3,1:nsc)=std(Q_MBFyear2(:,1:nsc));
    Q_MBFyearstats(4,1:nsc)=min(Q_MBFyear2(:,1:nsc));
    Q_MBFyearstats(5,1:nsc)=max(Q_MBFyear2(:,1:nsc));
    
    Q_MIFyearstats(1,1:nsc)=mean(Q_MIFyear2(:,1:nsc));
    Q_MIFyearstats(2,1:nsc)=median(Q_MIFyear2(:,1:nsc));
    Q_MIFyearstats(3,1:nsc)=std(Q_MIFyear2(:,1:nsc));
    Q_MIFyearstats(4,1:nsc)=min(Q_MIFyear2(:,1:nsc));
    Q_MIFyearstats(5,1:nsc)=max(Q_MIFyear2(:,1:nsc));       
    
    Q_MOFyearstats(1,1:nsc)=mean(Q_MOFyear2(:,1:nsc));
    Q_MOFyearstats(2,1:nsc)=median(Q_MOFyear2(:,1:nsc));
    Q_MOFyearstats(3,1:nsc)=std(Q_MOFyear2(:,1:nsc));
    Q_MOFyearstats(4,1:nsc)=min(Q_MOFyear2(:,1:nsc));
    Q_MOFyearstats(5,1:nsc)=max(Q_MOFyear2(:,1:nsc));      
   
%  Changes of mean and median (as compared to historical mean and median) for each GCM
    Q_MTFyearDeltastats=NaN(2,nsc);
    Q_MBFyearDeltastats=NaN(2,nsc);
    Q_MIFyearDeltastats=NaN(2,nsc);
    Q_MOFyearDeltastats=NaN(2,nsc);    
    
    for stat=1:2
        Q_MTFyearDeltastats(stat,1:nsc)=(Q_MTFyearstats(stat,1:nsc)-Q_MTFyearstats(stat,1))./Q_MTFyearstats(stat,1);
        Q_MBFyearDeltastats(stat,1:nsc)=(Q_MBFyearstats(stat,1:nsc)-Q_MBFyearstats(stat,1))./Q_MBFyearstats(stat,1);
        Q_MIFyearDeltastats(stat,1:nsc)=(Q_MIFyearstats(stat,1:nsc)-Q_MIFyearstats(stat,1))./Q_MIFyearstats(stat,1);
        Q_MOFyearDeltastats(stat,1:nsc)=(Q_MOFyearstats(stat,1:nsc)-Q_MOFyearstats(stat,1))./Q_MOFyearstats(stat,1);
    end

% vizualization 
    f1=figure('name','Cumulative discharge');
            subplot(2,2,1,'fontsize',10);
            plot(Date(:,1),Q_MTFcum(1:nTime,2:nsc)*f/area,'color',[0.6 0.6 0.6]);
            hold on
            plot(Date(:,1),Q_MTFcum(1:nTime,1)*f/area,'color','k','LineWidth',2);
            ylabel('Total flow (mm)')
            set(gca,'box','off');
            
            subplot(2,2,2,'fontsize',10);
            plot(Date(:,1),Q_MBFcum(1:nTime,2:nsc)*f/area,'color',[0.6 0.6 0.6]);
            hold on
            plot(Date(:,1),Q_MBFcum(1:nTime,1)*f/area,'color','k','LineWidth',2);
            ylabel('Baseflow (mm)')
            set(gca,'box','off');
            
            subplot(2,2,3,'fontsize',10);
            plot(Date(:,1),Q_MIFcum(1:nTime,2:nsc)*f/area,'color',[0.6 0.6 0.6]);
            hold on
            plot(Date(:,1),Q_MIFcum(1:nTime,1)*f/area,'color','k','LineWidth',2);
            ylabel('Interflow (mm)')
            set(gca,'box','off');
            
            subplot(2,2,4,'fontsize',10);
            plot(Date(:,1),Q_MOFcum(1:nTime,2:nsc)*f/area,'color',[0.6 0.6 0.6]);
            hold on
            plot(Date(:,1),Q_MOFcum(1:nTime,1)*f/area,'color','k','LineWidth',2);
            ylabel('Overland flow (mm)')
            set(gca,'box','off');    
    
     f2=figure('name','Median yearly discharge changes - GCM variation');
            sub(1)=subplot(1,6,1:2,'fontsize',10);
            boxplot(Q_MTFyearDeltastats(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            ylabel('Median annual flow change (%)')
            title('total flow')
            axis([xlim, -10,30])
            set(gca,'box','off')
            
            sub(2)=subplot(1,5,3,'fontsize',10);
            boxplot(Q_MBFyearDeltastats(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            title('baseflow')
            set(gca,'box','off','YTick',[])
            
            sub(3)=subplot(1,5,4,'fontsize',10);
            boxplot(Q_MIFyearDeltastats(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            title('interflow')
            set(gca,'box','off','YTick',[])
            
            sub(4)=subplot(1,5,5,'fontsize',10);
            boxplot(Q_MOFyearDeltastats(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            title('overland flow')
            set(gca,'box','off','YTick',[])
            
            linkaxes(sub,'y')       
            
% 8.4 Analyse with focus on GCM & interannual variability 
% -----------------------------------------------------------------------     
% stats for all GCMs & different years together (historical set excluded)
    Q_MTBIOFyearstats=NaN(5,4);
    
    Q_MTFyear2fut=Q_MTFyear2(:,2:nsc);%select all columns of future
    Q_MBFyear2fut=Q_MBFyear2(:,2:nsc);
    Q_MIFyear2fut=Q_MIFyear2(:,2:nsc);
    Q_MOFyear2fut=Q_MOFyear2(:,2:nsc);
    
    Q_MTBIOFyearstats(1,1)=mean(Q_MTFyear2fut(:));
    Q_MTBIOFyearstats(2,1)=median(Q_MTFyear2fut(:));
    Q_MTBIOFyearstats(3,1)=std(Q_MTFyear2fut(:));
    Q_MTBIOFyearstats(4,1)=min(Q_MTFyear2fut(:));
    Q_MTBIOFyearstats(5,1)=max(Q_MTFyear2fut(:));
    
    Q_MTBIOFyearstats(1,2)=mean(Q_MBFyear2fut(:));
    Q_MTBIOFyearstats(2,2)=median(Q_MBFyear2fut(:));
    Q_MTBIOFyearstats(3,2)=std(Q_MBFyear2fut(:));
    Q_MTBIOFyearstats(4,2)=min(Q_MBFyear2fut(:));
    Q_MTBIOFyearstats(5,2)=max(Q_MBFyear2fut(:));
    
    Q_MTBIOFyearstats(1,3)=mean(Q_MIFyear2fut(:));
    Q_MTBIOFyearstats(2,3)=median(Q_MIFyear2fut(:));
    Q_MTBIOFyearstats(3,3)=std(Q_MIFyear2fut(:));
    Q_MTBIOFyearstats(4,3)=min(Q_MIFyear2fut(:));
    Q_MTBIOFyearstats(5,3)=max(Q_MIFyear2fut(:));       
    
    Q_MTBIOFyearstats(1,4)=mean(Q_MOFyear2fut(:));
    Q_MTBIOFyearstats(2,4)=median(Q_MOFyear2fut(:));
    Q_MTBIOFyearstats(3,4)=std(Q_MOFyear2fut(:));
    Q_MTBIOFyearstats(4,4)=min(Q_MOFyear2fut(:));
    Q_MTBIOFyearstats(5,4)=max(Q_MOFyear2fut(:)); 
    
    clear Q_MOFyear2fut Q_MBFyear2fut Q_MTFyear2fut Q_MIFyear2fut

% Change of yearly discharge as compared to historical median for all years

    Q_MTFyearDelta=(Q_MTFyear2-Q_MTFyearstats(2,1))./Q_MTFyearstats(2,1);
    Q_MBFyearDelta=(Q_MBFyear2-Q_MBFyearstats(2,1))./Q_MBFyearstats(2,1);
    Q_MIFyearDelta=(Q_MIFyear2-Q_MIFyearstats(2,1))./Q_MIFyearstats(2,1);
    Q_MOFyearDelta=(Q_MOFyear2-Q_MOFyearstats(2,1))./Q_MOFyearstats(2,1);

% vizualization                  
f3=figure('name','Median yearly discharge absolute- GCM&year variation');% boxplot = variation over different GCMs & over 30 different year)   

        sub(1)=subplot(1,6,1:2,'fontsize',10);
        boxplot(Q_MTFyear2(:,1:nsc),groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[Q_MTFyearstats(2,1),Q_MTFyearstats(2,1)],'Color','k','LineStyle','--')
        ylabel('Annual flow(mm/year)')
        title('total flow')
        axis([xlim, 0,550])
        set(gca,'box','off')

        sub(2)=subplot(1,5,3,'fontsize',10);
        boxplot(Q_MBFyear2(:,1:nsc),groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[Q_MBFyearstats(2,1),Q_MBFyearstats(2,1)],'Color','k','LineStyle','--')
        title('baseflow')
        set(gca,'box','off','YTick',[])

        sub(3)=subplot(1,5,4,'fontsize',10);
        boxplot(Q_MIFyear2(:,1:nsc),groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[Q_MIFyearstats(2,1),Q_MIFyearstats(2,1)],'Color','k','LineStyle','--')
        title('interflow')
        set(gca,'box','off','YTick',[])

        sub(4)=subplot(1,5,5,'fontsize',10);
        boxplot(Q_MOFyear2(:,1:nsc),groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[Q_MOFyearstats(2,1),Q_MOFyearstats(2,1)],'Color','k','LineStyle','--')
        title('overland flow')
        set(gca,'box','off','YTick',[])

        linkaxes(sub,'y')

f4=figure('name','Median yearly discharge changes- GCM&year variation');% boxplot = variation over different GCMs & over 30 different year)   

        sub(1)=subplot(1,6,1:2,'fontsize',10);
        boxplot(Q_MTFyearDelta(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[0,0],'Color','k','LineStyle','--')
        ylabel('Annual flow change from historical median (%)')
        title('total flow')
        axis([xlim, -100,100])
        set(gca,'box','off')

        sub(2)=subplot(1,5,3,'fontsize',10);
        boxplot(Q_MBFyearDelta(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[0,0],'Color','k','LineStyle','--')
        title('baseflow')
        set(gca,'box','off','YTick',[])

        sub(3)=subplot(1,5,4,'fontsize',10);
        boxplot(Q_MIFyearDelta(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[0,0],'Color','k','LineStyle','--')
        title('interflow')
        set(gca,'box','off','YTick',[])

        sub(4)=subplot(1,5,5,'fontsize',10);
        boxplot(Q_MOFyearDelta(:,1:nsc)*100,groupmat(1,1:nsc),'grouporder',groupnames2,'labels',groupnames2)
        line(xlim,[0,0],'Color','k','LineStyle','--')
        title('overland flow')
        set(gca,'box','off','YTick',[])

        linkaxes(sub,'y')  
        
% 8.5 Analyse probabilities with cumulative distribution function  
% -----------------------------------------------------------------------
% normality check 
[notnormalTF,~]=NormalityCheck(Q_MTFyear2,'lillie',0.05);
[notnormalBF,~]=NormalityCheck(Q_MBFyear2,'lillie',0.05);
[notnormalIF,~]=NormalityCheck(Q_MIFyear2,'lillie',0.05);
[notnormalOF,~]=NormalityCheck(Q_MOFyear2,'lillie',0.05);

if isempty(notnormalTF)==1 && isempty(notnormalBF)==1 && isempty(notnormalIF)==1 && isempty(notnormalOF)==1
    disp('All flow values for all scenarios are normally distributed')
else
    if isempty(notnormalTF)==0
    warning(['Total flow is not normally distributed for scenarios: ',num2str(notnormalTF.')])
    end
    
    if isempty(notnormalBF)==0
    warning(['Baseflow is not normally distributed for scenarios: ',num2str(notnormalBF.')])
    end
    
    if isempty(notnormalIF)==0
    warning(['Interflow is not normally distributed for scenarios: ',num2str(notnormalIF.')])
    end
    
    if isempty(notnormalOF)==0
    warning(['Overland flow is not normally distributed for scenarios: ',num2str(notnormalOF.')])
    end
end       
    
clear notnormalTF notnormalBF notnormalIF notnormalOF 

% fit theoretical normal distributions
xrangeTF=0:5:max(Q_MTFyear2(:));
xrangeBF=0:5:max(Q_MBFyear2(:));
xrangeIF=0:5:max(Q_MIFyear2(:));
xrangeOF=0:5:max(Q_MOFyear2(:));

probabilitiesTF=NaN(length(xrangeTF),nsc);
probabilitiesBF=NaN(length(xrangeBF),nsc);
probabilitiesIF=NaN(length(xrangeIF),nsc);
probabilitiesOF=NaN(length(xrangeOF),nsc);

for sc=1:nsc
pdsc=fitdist(Q_MTFyear2(:,sc),'Normal');
probabilitiesTF(:,sc)=cdf(pdsc,xrangeTF);

pdsc=fitdist(Q_MBFyear2(:,sc),'Normal');
probabilitiesBF(:,sc)=cdf(pdsc,xrangeBF);

pdsc=fitdist(Q_MIFyear2(:,sc),'Normal');
probabilitiesIF(:,sc)=cdf(pdsc,xrangeIF);

pdsc=fitdist(Q_MOFyear2(:,sc),'Normal');
probabilitiesOF(:,sc)=cdf(pdsc,xrangeOF);

end
clear pdsc 

% vizualize
f5=figure('name','Yearly discharge theoretical CDF');
    subplot(2,2,1,'fontsize',10);
    P=plot(xrangeTF,probabilitiesTF(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual total flow (mm/year)','fontsize',8);
    title('Total flow')
    set(gca,'box','off')

    subplot(2,2,2,'fontsize',10);
    P=plot(xrangeBF,probabilitiesBF(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual baseflow (mm/year)','fontsize',8);
    title('Baseflow')
    set(gca,'box','off') 
    
    subplot(2,2,3,'fontsize',10);
    P=plot(xrangeIF,probabilitiesIF(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual interflow (mm/year)','fontsize',8);
    title('Interflow')
    set(gca,'box','off')
    
    subplot(2,2,4,'fontsize',10);
    P=plot(xrangeOF,probabilitiesOF(:,1:nsc));   
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual overland flow (mm/year)','fontsize',8);
    title('Overland flow')
    set(gca,'box','off')

    
f6=figure('name','Yearly discharge emperical CDF');
    subplot(2,2,1,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Q_MTFyear2(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual total flow (mm/year)','fontsize',8);
    title('Total flow')
    set(gca,'box','off')
    grid off

    subplot(2,2,2,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Q_MBFyear2(:,i));
        hold on 
    end
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual baseflow (mm/year)','fontsize',8);
    title('Baseflow')
    set(gca,'box','off') 
    grid off
    
    subplot(2,2,3,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Q_MIFyear2(:,i));
        hold on 
    end  
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual interflow (mm/year)','fontsize',8);
    title('Interflow')
    set(gca,'box','off')
    grid off
    
    subplot(2,2,4,'fontsize',10);
    for i=1:nsc
        P(i)=cdfplot(Q_MOFyear2(:,i));
        hold on 
    end    
    set(P,{'Color'},colorstruct,{'LineStyle'},linesstruct,{'LineWidth'},linewstruct)
    ylabel('Cumulative probability','fontsize',8);
    xlabel('Annual overland flow (mm/year)','fontsize',8);
    title('Overland flow')
    set(gca,'box','off')
    grid off
    
 clear xrangeTF xrangeBF xrangeIF xrangeOF   
            
% 8.6 save results (vizualizations)
% ----------------------------------------------------------------------- 
filename='Discharge - cumulative';
filename=fullfile(DatapathScenOut,filename);
savefig(f1,filename)

filename='Yearly discharge median changes-gcmboxplot';
filename=fullfile(DatapathScenOut,filename);
savefig(f2,filename)

filename='Yearly discharge median changes-yeargcmboxplot';
filename=fullfile(DatapathScenOut,filename);
savefig(f4,filename)

filename='Yearly discharge emperical CDF';
filename=fullfile(DatapathScenOut,filename);
savefig(f6,filename)

clear filename sub
%% -----------------------------------------------------------------------
% 9. MONTHLY DISCHARGE IMPACT (Only QTF) 
%------------------------------------------------------------------------

% reorganize data in one matrix   
    Q_MTFymonth2=cell(1,12);

    for m=1:12
        mindex=find(Q_MTFymonth{1,1}(:,2)==m);
        for sc =1:nsc
        Q_MTFymonth2{1,m}(:,sc)=Q_MTFymonth{1,sc}(mindex,3);
        end
    end

% stats for each month and each scenario
    Q_MTFmonthstats=cell(2,12);
    Q_MTFmonthstats(1,1:12)={'jan','febr','march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'};
    
    for m=1:12 
        Q_MTFmonthstats{2,m}(1,1:nsc)=mean(Q_MTFymonth2{1,m}(:,1:nsc));
        Q_MTFmonthstats{2,m}(2,1:nsc)=median(Q_MTFymonth2{1,m}(:,1:nsc));
        Q_MTFmonthstats{2,m}(3,1:nsc)=std(Q_MTFymonth2{1,m}(:,1:nsc));
        Q_MTFmonthstats{2,m}(4,1:nsc)=min(Q_MTFymonth2{1,m}(:,1:nsc));
        Q_MTFmonthstats{2,m}(5,1:nsc)=max(Q_MTFymonth2{1,m}(:,1:nsc));
    end
    
%  Mean changes of statistics (mean and median)for each month and each
%  scenario
    Q_MTFmonthDeltastats=cell(2,12);
    Q_MTFmonthDeltastats(1,1:12)=Q_MTFmonthstats(1,1:12);
   
    for m=1:12 
        for stat=1:2
            Q_MTFmonthDeltastats{2,m}(stat,1:nsc)=(Q_MTFmonthstats{2,m}(stat,1:nsc)-Q_MTFmonthstats{2,m}(stat,1))./Q_MTFmonthstats{2,m}(stat,1);
        end
    end
    
% vizualization (boxplot= variation over different GCMs)     
    figure('name','Median monthly discharge changes')
            sub(1)=subplot('Position',[0.05, 0.4, 0.055,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,1}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            ylabel('Median monthly flow change (%)')
            xlabel('January')
            axis([xlim, -60,60])
            set(gca,'XTick',[])
            set(gca,'box','off')
            
            sub(2)=subplot('Position',[0.16, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,2}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('February')           
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
            
            sub(3)=subplot('Position',[0.2208, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,3}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('March')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
            
            sub(4)=subplot('Position',[0.28, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,4}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('April')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')

            sub(5)=subplot('Position',[0.3355, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,5}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('May')
             set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
            
            sub(6)=subplot('Position',[0.401, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,6}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('June')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
            
            title('Changes of median monthly discharge')            
            sub(7)=subplot('Position',[0.46, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,7}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('July')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
          
            sub(8)=subplot('Position',[0.525, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,8}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('August')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
          
            sub(9)=subplot('Position',[0.587, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,9}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('September')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
              
            sub(10)=subplot('Position',[0.64, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,10}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('October')  
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
          
            sub(11)=subplot('Position',[0.725, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,11}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('November')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')
          
            sub(12)=subplot('Position',[0.785, 0.4, 0.04,0.55],'fontsize',10); 
            boxplot(Q_MTFmonthDeltastats{2,12}(1,2:nsc)*100,groupmat(1,2:nsc),'grouporder',groupnames,'labels',groupnames);
            line(xlim,[0,0],'Color','k','LineStyle','--')
            xlabel('December')
            set(gca,'YTick',[],'XTick',[])
            set(gca,'box','off')     
            linkaxes(sub,'y')% link y axis of different plots (so that they change simultaneously
            
            subplot('Position',[0.06, 0.1, 0.76,0.2],'fontsize',12);
                for i=1:12
                HistValue(i,1)=Q_MTFmonthstats{2,i}(1,2);
                end
            bar(1:12,HistValue)
            ylabel('Median monthly flow (mm/month)','fontsize',10)
            axis([0.5,12.5, ylim])
            set(gca,'XTick',1:12)
            set(gca,'box','off')
            
% save vizualization
filename='Monthly Discharge - median changes GCM boxlplots';
filename=fullfile(DatapathScenOut,filename);
savefig(filename)            
            
%% -----------------------------------------------------------------------
% 8. SOWING DATE CONDITIONS ANALYSIS
%------------------------------------------------------------------------

% 8.1 Write necessary data in matrix per crop
% ----------------------------------------------------------------------- 

% SOWING DATES: the sowing date is calculated in the section where potential length of
% growing period is calculated

% SOIL WATER CONTENT: Wr2 contains the soil water content in 2 m depth for each landunit and each scenario

% Calculate the soil water content for each crop & scenario & soil type for
% all days
% Wr2= soil water content in 2 m depth for each landunit and each scenario
% Wr2Sil/Wr2Sal= soil water content in 2 m on average for each landunit with a certain crop and soil type 

    Wr2SiL=cell(2,ncrop);
    Wr2SaL=cell(2,ncrop);

    Wr2SiL(1,1:ncrop)=Cropnames(1,1:ncrop);
    Wr2SaL(1,1:ncrop)=Cropnames(1,1:ncrop);

    for sc=1:nsc
        for c=1:ncrop
           name=Cropnames(1,c); 
           luindex1=find(strcmp(Crop(:,1),name)==1); 

           % analyse for soil type 1 (SiL)
           luindex2=find(strcmp(Soil(:,1),'SiL')==1);
           luindex=intersect(luindex1,luindex2);
           Wr2SiL{2,c}(:,sc)= mean(Wr2{2,sc}(:,luindex),2); % more than one lu with same crop and soil then take average
           clear luindex2 luindex 
           % analyse for soil type 2 (SaL) 
           luindex2=find(strcmp(Soil(:,1),'SaL')==1);
           luindex=intersect(luindex1,luindex2);
           Wr2SaL{2,c}(:,sc)= mean(Wr2{2,sc}(:,luindex),2);
           clear luindex2 luindex
        end  
        clear luindex1
    end

% TEMPERATURE: Tmin en Tmax contain the minimum en maximum temperature for
%  each scenario

% GDD: contains the GDD for each landunit and each scenario


% 8.2 Calculate Temperature around sowing 
% ----------------------------------------------------------------------- 



% 8.3 Calculate Soil water content around sowing 
% ----------------------------------------------------------------------- 
% specify window in which SWC before sowing date has to be checked
    window=10; 
% initialize
    Wr2SiLsowing=cell(2,ncrop);
    Wr2SaLsowing=cell(2,ncrop);
    Wr2SiLsowing(1,1:ncrop)=Cropnames(1,1:ncrop);
    Wr2SaLsowing(1,1:ncrop)=Cropnames(1,1:ncrop);
    
% define SWC in window around sowing date 
    for sc=1:nsc 
        for c=1:ncrop
            for y=1:nyear
                d=sowing{2,c}(y,sc);
                indexdate=datefind(d, Date(:,sc),0);
                Wr2SiLsowing{2,c}(y,sc)=mean(Wr2SiL{2,c}(indexdate-(window-1):indexdate,sc));
                Wr2SaLsowing{2,c}(y,sc)=mean(Wr2SaL{2,c}(indexdate-(window-1):indexdate,sc));
            end
        end
    end

% Take median of all years
    Wr2sowing=cell(3,ncrop+1);
    Wr2sowing(1,2:ncrop+1)=Cropnames(1,1:ncrop);
    Wr2sowing(2,1)={'SiL'};
    Wr2sowing(3,1)={'SaL'};
    for c=1:ncrop
     Wr2sowing{2,c+1}(1,1:nsc)=median(Wr2SiLsowing{2,c}(:,1:nsc),'omitnan')./(SoilPar(1,1)*2); % mean over all years, expresed relative to FC
     Wr2sowing{3,c+1}(1,1:nsc)=median(Wr2SaLsowing{2,c}(:,1:nsc),'omitnan')./(SoilPar(1,2)*2);   
    end

clear window Wr2SiL Wr2SaL c sc d y
    

% 8.4 shows graphs
% -----------------------------------------------------------------------
%vizualize for scenario ?
scenario=1;

% select data of this scenario
for c=1:ncrop
matrix(c,1)=Wr2sowing{2,c+1}(1,scenario);
matrix(c,2)=Wr2sowing{3,c+1}(1,scenario);
end

% make figures
figure('name','SWC around sowing date')
    bar(matrix)
    set(gca,'xticklabel',Cropnames)

clear matrix c scenario

% 8.x save results (vizualizations)
% ----------------------------------------------------------------------- 

%% -----------------------------------------------------------------------
% 9. SUMMARY TABLES
%------------------------------------------------------------------------
xlname='SummaryTables.xlsx';
filename = fullfile(DatapathScenOut,xlname);

% Summary of annual discharge (median and changes to median)
HeadersColumns={'Historical median','Future median change min','Future median change med','Future median change max'};
HeadersRows={'Annual Qtot';'Annual QBF';'Annual QIF';'Annual QOF'};
Row1=
Row2=
Row3=
Row4=
DataMatrix=[Row1;Row2,Row3;Row4]

xlswrite(filename,HeadersColumns,'Discharge','A1');
xlswrite(filename,HeadersRows,'Discharge','A2');

    
        




% write output for this scenario to excel      
      % Combine output in matrix if necessary
        HeadersColumns={'Historical median','Future median change min','Future median change med','Future median change max'};
        HeadersRows={'Seasonal crop yield';'CV yield';'WPET';'LGPact';'TSI';'DSI';'Annual Qtot';'Annual QBF';'Annual QIF';'Annual QOF'};
        Row1=[
                         
                   
                    
         DataMatrix=[Row1;Row2,Row3;Row4;Row5;Row6;Row7;Row8;Row9;Row10];