classdef batteryPack < lfpBattery.batteryInterface
%BATTERYPACK: Cell-resolved model of a lithium ion battery pack.
%
%
% BATTERYPACK Methods:
% powerRequest      - Requests a power in W (positive for charging, 
%                     negative for discharging) from the battery.
% iteratePower      - Iteration to determine new state given a certain power.
% currentRequest    - Requests a current in A (positive for charging,
%                     negative for discharging) from the battery.
% iterateCurrent    - Iteration to determine new state given a certain current.
% addCounter        - Registers a cycleCounter object as an observer.
% dischargeFit      - Uses Levenberg-Marquardt algorithm to fit a
%                     discharge curve.
% initAgeModel      - Initializes the age model of the battery.
% getNewVoltage     - Returns the new voltage according to a current and a
%                     time step size.
% addcurves         - Adds a collection of discharge curves or a cycle
%                     life curve to the battery.
%
%
% BATTERYPACK Properties:
% C                 - Current capacity level in Ah.
% Cbu               - Useable capacity in Ah.
% Cd                - Discharge capacity in Ah (Cd = 0 if SoC = 1).
% Cn                - Nominal (or average) capacity in Ah.
% eta_bc            - Efficiency when charging [0,..,1].
% eta_bd            - Efficiency when discharging [0,..,1].
% Imax              - Maximum current in A.
% psd               - Self discharge rate in 1/month [0,..,1].
% SoC               - State of charge [0,..,1].
% socMax            - Maximum SoC (default: 1).
% socMin            - Minimum SoC (default: 0.2).
% SoH               - State of health [0,..,1].
% V                 - Resting voltage in V.
% Vn                - Nominal (or average) voltage in V.
% Zi                - Internal impedance in Ohm.
%
% BATTERYPACK Settable Properties:
% maxIterations     - Maximum number of iterations in iteratePower()
%                     and iterateCurrent() methods.
% pTol              - Tolerance for the power iteration in W.
% sTol              - Tolerance for SoC limitation iteration.
% iTol              - Tolerance for current limitation iteration in A.
%
%
%Authors: Marc Jakobi, Festus Anynagbe, Marc Schmidt
%         January 2017
%
%%SEE ALSO: lfpBattery.batCircuitElement lfpBattery.seriesElement
%          lfpBattery.seriesElementPE lfpBattery.seriesElementAE
%          lfpBattery.parallelElement lfpBattery.simplePE
%          lfpBattery.simpleSE lfpBattery.batteryCell
%          lfpBattery.batteryAgeModel lfpBattery.eoAgeModel
%          lfpBattery.dambrowskiCounter lfpBattery.cycleCounter
    properties (SetAccess = 'immutable')
        AgeModelLevel;
    end
    properties (Dependent)
        V; % Resting voltage of the battery pack in V
    end
    properties (Dependent, SetAccess = 'protected')
        % Discharge capacity in Ah (Cd = 0 if SoC = 1).
        % The discharge capacity is given by the nominal capacity Cn and
        % the current capacity C at SoC.
        % Cd = Cn - C
        Cd;
        % Current capacity level in Ah.
        C;
    end
    properties (Dependent, SetAccess = 'immutable')
        % Internal impedance of the battery pack in Ohm.
        % The internal impedance is currently not used as a physical
        % parameter. However, it is used in the circuit elements
        % (seriesElement/parallelElement) to determine the distribution
        % of currents and voltages.
        Zi;
    end
    
    methods
        function b = batteryPack(Cp, Vp, Cc, Vc, varargin)
%BATTERYPACK: Initializes a cell-resolved model of a lithium ion battery pack.
%
%Syntax:
%       b = BATTERYPACK(Cp, Vp, Cc, Vc);
%           Initializes a battery pack with the nominal cell voltae Vc and the 
%           nominal cell capacity Cc. The cells are arranged as strings of 
%           parallel cells in such a way that the pack's nominal voltage Vp
%           and capacity Cp come as close as possible to the inputs Cp and Vp.
%
%       b = BATTERYPACK(np, ns, Cc, Vc, 'SetUp', 'Manual');
%           Initializes a battery pack with the nominal cell voltae Vc and the 
%           nominal cell capacity Cc. The cells are arranged as ns strings of
%           parallel elements with np parallel cells. The pack's nominal capacity 
%           depends on the cell voltage Vc and on the number of parallel cells np.
%           The pack's nominal voltage depends on the cell voltage Vc and on the
%           number of elements per string ns.
%
%       b = BATTERYPACK(..., 'OptionName', OptionValue)
%           Used for specifying additional options, which are described below. 
%           The option names must be specified as strings.
%
%Input arguments:
%
%   Cp  -  Battery pack nominal capacity in Ah.
%   Vp  -  Battery pack nominal voltage in V.
%   Cc  -  Cell capacity (nominal) in Ah.
%   Vc  -  Cell voltage (nominal) in V.
%   np  -  Number of elements per parallel element.
%   ns  -  Number of elements per string.
%
%Additional Options:
%
%   'ageModel'                - 'none' (default), 'EO', or a custom age model object
%                               that implements the batteryAgeModel interface.
%                               -> 'EO' = event oriented aging model (eoAgeModel object)
%
%   'AgeModelLevel'           - 'Pack' (default) or 'Cell'
%                             -> Specifies whether the age model is applied to the pack
%                             or to each cell individually. Applying the age model to the 
%                             pack should result in faster simulation times.
%
%   'cycleCounter'            - 'auto' (default), 'dambrowski' or a custom cycle counter
%                               object that implements the cycleCounter
%                               interface. By default, no cycle counter is
%                               implemented if 'ageModel' is set to 'none',
%                               otherwise the 'dambrowski' counter is used.
%
%   'Equalization'            - 'Passive' (default) or 'Active'.
%                             -> Specifies which type of equalization (balancing)
%                             is used for the strings in the pack.
%
%   'etaBC'                   - default: 0.97
%                             -> The battery pack's charging efficiency. If
%                             the data sheets do not differentiate between
%                             charging and discharging efficiency, set 
%                             'etaBC' to the given efficiency and set 'etaBD'
%                             to 1.
%
%   'etaBD'                   - default: 0.97
%                             -> The battery pack's discharging efficiency. 
%                             Set this to 1 if the data sheets do not
%                             differentiate between charging and discharging
%                             efficiencies.
%
%   'ideal'                   - true or false (default)
%                             -> Set this to true to simulate a simpler
%                             model with ideal cells and balancing. Setting
%                             this to true assumes all cells have exactly
%                             the same parameters and that the balancing is
%                             perfect. This should result in much fewer
%                             resources during simulation, as only one cell
%                             is used for calculations.
%
%   'socMax'                 - default: 1
%                             -> Upper limit for the battery pack's state of
%                             charge SoC.
%   
%   'socMin'                 - default: 0.2
%                             -> Lower limit for the battery pack's SoC.
%                             Note that the SoC can go below this limit if
%                             it is above 0 and if a self-discharge has
%                             been specified.
%   
%   'socIni'                 - default: 0.2
%                             -> Initialial SoC of the battery pack.
%
%   'sohIni'                 - default: 1
%                             -> Initial state of health SoH of the battery
%                             pack and/or cells (depending on the
%                             'AgeModelLevel')
%
%   'Topology'               - 'SP' (default) or 'PS'
%                             -> The topology of the pack's circuitry. 'SP' 
%                             for strings of parallel cells and 'PS' for
%                             parallel strings of cells.
%
%   'Zi'                     - default: 17e-3
%                             -> Internal impedance of the cells in Ohm. 
%                             The internal impedance is currently not used 
%                             as a physical parameter. However, it is used 
%                             in the circuit elements to determine the
%                             distribution of currents and voltages.
%                               
%   'Zstd'                   - default: 0
%                            -> Standard deviation of the battery cells'
%                            internal impedances in Ohm. This setting is
%                            ignored if the 'ideal' option is set to true.
%                            
%   'dCurves'                - default: 'none'
%                            -> adds dischargeCurve object to the battery's
%                            cells.
%
%   'ageCurve'               - default: 'none'
%                            -> adds an age curve (e. g. a woehlerFit) to
%                            the battery's cells.

            import lfpBattery.*
            p = lfpBattery.batteryInterface.bInputParser; % load default optargs
            % add additional optargs to parser
            valid = {'Pack', 'Cell'};
            addOptional(p, 'AgeModelLevel', 'Pack', @(x) any(validatestring(x, valid)))
            valid = {'SP', 'PS'}; % strings of parallel elements / parallel strings
            addOptional(p, 'Topology', 'SP', @(x) any(validatestring(x, valid)))
            valid = {'Passive', 'Active'};
            addOptional(p, 'Equalization', 'Passive', @(x) any(validatestring(x, valid)))
            valid = {'Auto', 'Manual'};
            addOptional(p, 'SetUp', 'Auto', @(x) any(validatestring(x, valid)))
            addOptional(p, 'ideal', false, @islogical)
            addOptional(p, 'Zstd', 0, @isnumeric)
            addOptional(p, 'dCurves', 'none', @(x) lfpBattery.batteryPack.validateCurveOpt(x,...
                'lfpBattery.curvefitCollection'))
            addOptional(p, 'ageCurve', 'none', @(x) lfpBattery.batteryPack.validateCurveOpt(x,...
                'lfpBattery.curveFitInterface'))
            % parse inputs
            parse(p, varargin{:})
            % prepare age model and cycle counter params at pack/cell levels
            amL = p.Results.AgeModelLevel;
            am = p.Results.ageModel;
            cy = p.Results.cycleCounter;
            if strcmp(amL, 'Cell')
                if ~strcmp(am, 'none')
                    cellAm = am; % cell age model arg
                    packAm = 'LowerLevel'; % pack age model arg
                    cellCy = cy;
                    packCy = 'auto';
                else % no age model
                    cellAm = am;
                    packAm = am;
                    cellCy = 'auto';
                    packCy = 'auto';
                end
            else
                cellAm = 'none';
                packAm = am;
                cellCy = 'auto';
                packCy = cy;
            end
            sohIni = p.Results.sohIni;
            socIni = p.Results.socIni;
            socMin = p.Results.socMin;
            socMax = p.Results.socMax;
            commonArgs = {'sohIni', sohIni, 'socIni', socIni,...
                'socMin', socMin, 'socMax', socMax};
            % Initialize with superclass constructor
            b@lfpBattery.batteryInterface('ageModel', packAm, 'cylceCounter', packCy, ...
                commonArgs{:});
            % Additional inputs
            b.AgeModelLevel = p.Results.AgeModelLevel;
            sp = strcmp(p.Results.Topology, 'SP');
            pe = strcmp(p.Results.Equalization, 'Passive');
            im = p.Results.ideal;
            Zstd = p.Results.Zstd;
            dC = p.Results.dCurves;
            aC = p.Results.ageCurve;
            if strcmp(p.Results.SeUp, 'Auto') % automatic setup?
                np = uint32(Cp ./ Cc); % number of parallel elements
                ns = uint32(Vp ./ Vc); % number of series elements
            else % user-defined setup
                np = uint32(Cp);
                ns = uint32(Vp);
            end
            
            if im % simple, ideal model
                if sp % strings of parallel elements
                    b.El = simpleSE(simpleSP(batteryCell(Cc, Vc, 'ageModel', cellAm, ...
                        'cycleCounter', cellCy, 'Zi', p.Results.Zi, commonArgs{:}),...
                        ns), np);
                else % parallel strings of cells
                    b.El = simpleSP(simpleSE(batteryCel(Cc, Vc, 'ageModel', cellAm, ...
                        'cycleCounter', cellCy, 'Zi', p.Results.Zi, commonArgs{:}),...
                        np), ns);
                end
            else % non-simplified model             MTODO: Finish this!
                if sp % strings of parallel elements
                    if pe % passive equalization
                        for j = 1:uint32(np)
                            for i = uint32(1):ns % initiate cells
                                
                            end
                            % initiate parallel elements
                        end
                    else % active equalization
                        
                    end
                else % parallel strings of cells
                    if pe % passive equalization
                        
                    else % active equalization
                        
                    end
                end
            end
            
            % pass curve fits
            if strcmp(dC, 'none')
                warning(['Battery pack initialized without discharge curve fits.', ...
                    'Add curve fits to the model using this class''s addcurves() method.', ...
                    'Attempting to use this model without discharge curve fits will result in an error.'])
            else
                b.addcurves(dC)
            end
            if strcmp(aC, 'none') && ~strcmp(aM, 'none')
                warning(['Battery pack initialized without cycle life curve fits although an age model was specified.', ...
                    'Add curve fits to the model using this class''s addcurves() method.', ...
                    'Attempting to use this model without cycle life curve fits will result in an error.'])
            else
                b.addcurves(aC, 'cycleLife')
            end
            
            
        end % constructor
        function addcurves(b, d, type)
            if nargin < 3
                type = 'discharge';
            end
            if strcmp(type, 'cycleLife') && strcmp(b.AgeModelLevel, 'Pack')
                b.ageModel.wFit = d;
            else
                b.pass2cells(@addcurves, d, type);
            end
        end
        %% MTODO: Add randomizeDC method
        function v = getNewVoltage(b, I, dt)
            v = b.El.getNewVoltage(I, dt);
        end
        %% getters & setters
        function set.V(b, v) %#ok<INUSD>
            % Cannot protect SetAcces any other way due to shared interface.
            error('Cannot set read-only property V in batteryPack.')
        end
        function v = get.V(b)
            v = b.El.V;
        end
        function c = get.Cd(b)
            c = b.El.Cd;
        end
        function c = get.C(b)
            c = b.El.C;
        end
        function z = get.Zi(b)
            z = b.El.Zi;
        end
    end
    
    methods (Access = 'protected')
        function pass2cells(b, fun, varargin)
            %PASS2CELLS: Passes the function specified by function handle fun
            %to all cells in this pack
            it = b.El.createIterator;
            while it.hasNext
                cell = it.next;
                feval(fun, cell, varargin{:});
            end
        end
        % Abstract methods passed on to El handle
        function charge(b, Q)
            b.El.charge(Q)
        end
        function c = dummyCharge(b, Q)
            c = b.El.dummyCharge(Q);
        end
        function refreshNominals(b)
            b.Vn = b.El.Vn;
            b.Cn = b.El.Cn;
        end
        function s = sohCalc(b)
            s = b.El.SoH;
        end
        function i = findImax(b)
            i = b.El.findImax;
            b.Imax = i;
        end
    end
    
    methods (Static, Access = 'protected')
        function validateCurveOpt(x, validInterface)
            if ~strcmp(x, 'none')
                lfpBattery.commons.validateInterface(x, validInterface)
            end
        end
    end
end