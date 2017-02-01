classdef curvefitCollection < lfpBattery.sortedFunctions & matlab.mixin.Copyable
    %CURVEFITCOLLECTION sorted collection of curveFit objects. Uses
    %interplation to extract data between two curve fits according to z
    %value
    %
    %CURVEFITCOLLECTION Properties:
    %
    %   xydata - cell array of curve fit objects (should implement curveFitInterface)
    %   z      - z data at which the respective curve measurements were
    %            recorded (i. e. temperature, current,...)
    %
    %CURVEFITCOLLECTION Methods:
    %
    %   add                 - Adds a curve fit object cf to a collection c.
    %   remove              - Removes the object with the z coordinate specified by z from the collection c.
    %   createIterator      - Returns an iterator.
    %
    %SEE ALSO: lfpBattery.curveFitInterface
    %
    %Authors: Marc Jakobi, Festus Anyangbe, Marc Schmidt
    %         January 2017
    
    properties (Abstract)
        interpMethod; % Method for interpolation (see interp1)
    end
    
    methods
        function c = curvefitCollection(varargin)
            %CURVEFITCOLLECTION  Initializes collection of curve fits, each with a single z value.
            %CURVEFITCOLLECTION(f1, f2, .., fn) Initializes collection with
            %                                curve fits f1, f2, .. up to fn
            %f1, f2, .., fn must implement the curveFitInterface.
            c@lfpBattery.sortedFunctions(varargin{:})
        end
        function y = interp(c, z, x)
            %INTERP returns interpolated result between calculations of
            %multiple curveFits.
            %Syntax: y = INTERP(z, x);  Returns y for the the coordinates
            %                           [z, x]
            feval(c.errHandler, c); % make sure there are enough functions in the collection
            % interpolate with available curve fit returns at 
            nEl = uint32(numel(c.xydata));
            xx = zeros(nEl, 1);
            for i = uint32(1):nEl
                tmp = c.xydata{i};
                xx(i) = tmp(x);
            end
            y = interp1(c.z, xx, z, c.interpMethod);
            % use commented out code below to limit y to curve fits in a
            % subclass
%             y = lfpBattery.commons.upperlowerlim(...
%                 interp1(c.z, c.xydata{x}, z, c.interpMethod, 'extrap'), ...
%                 min(c.y), max(c.y));
        end
        function add(c, d)
            %ADD: Adds a curve fit object cf to a collection c.
            %     Syntax: c.ADD(cf)
            %
            %If an object cf with the same z coordinate exists, the
            %existing one is replaced.
           c.validateInputInterface(d);
           c.add@lfpBattery.sortedFunctions(d);
        end
        function plotResults(c, varargin)
            %PLOTRESULTS: Compares scatters of the raw data with the fits
            %in a figure window.
            %PLOTRESULTS('OptionName', 'OptionValue') plots results
            %with additional options.
            %
            %Options:
            %   noRawData (logical) - don't scatter raw data (default: false)
            %   noFitData (logical) - don't scatter fit data (default: false)
            %   SoCx (logical)      - Scale x axis as SoC instead of discharge capacity for discharge curves (default: false)
            figure;
            hold on
            tmp = c.xydata{1};
            plotResults(tmp, false, varargin{:});
            if nargin < 3
                legend('raw data', 'fits', 'Location', 'Best')
            end
            grid on
            for i = 2:numel(c.xydata)
                tmp = c.xydata{i};
                plotResults(tmp, false, varargin{:});
            end
        end
    end
    
    methods (Access = 'protected')
        % gpuCompatible methods
        function setsubProp(obj, fn, val)
            obj.(fn) = val;
        end
        function val = getsubProp(obj, fn)
            val = obj.(fn);
        end
    end
    
    methods (Static)
        function validateInputInterface(obj)
            try % only curvefitCollection & curveFitInterface subclasses can be added
                lfpBattery.commons.validateInterface(obj, 'lfpBattery.curvefitCollection')
            catch
                lfpBattery.commons.validateInterface(obj, 'lfpBattery.curveFitInterface');
            end
        end
    end
end

