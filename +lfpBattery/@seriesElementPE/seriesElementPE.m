classdef seriesElementPE < lfpBattery.batCircuitElement
    %SERIESELEMENTPE battery elements connected in series with passive
    %equalization
    
    properties (Dependent)
        V;
    end
    properties (Dependent, SetAccess = 'protected')
        Cd;
    end
    properties (Dependent, SetAccess = 'immutable')
        Zi;
    end
    
    methods
        function b = seriesElementPE(varargin)
            b@lfpBattery.batCircuitElement(varargin{:})
        end
        function v = getNewVoltage(b, I, dt)
            v = sum(arrayfun(@(x) getNewVoltage(x, I, dt), b.El));
        end
        function v = get.V(b)
            v = sum([b.El.V]);
        end
        function set.V(b, v)
            % set voltages according to proportions of internal impedances
            p = b.getZProportions;
            v = v .* p(:);
            for i = uint32(1):b.nEl
                b.El(i).V = v(i);
            end
        end
        function c = get.Cd(b)
            c = max([b.El.Cd]); % total = Cn - min capacity = max discharge capacity
        end
        function z = get.Zi(b)
            z = sum([b.El.Zi]);
        end
    end
    
    methods (Access = 'protected')
        function i = findImax(b)
            i = min(findImax@lfpBattery.batCircuitElement(b));
            b.Imax = i;
        end
        function charge(b, Q)
            % Pass equal amount of discharge capacity to each element
            q = 1 ./ double(b.nEl) .* Q;
            charge@lfpBattery.batCircuitElement(b, q)
        end
        function p = getZProportions(b)
            % lowest impedance --> lowest voltage
            zv = [b.El.Zi]; % vector of internal impedances
            p = zv ./ sum(zv);
        end
        function refreshNominals(b)
            b.Vn = sum([b.El.Vn]);
            b.Cn = min([b.El.Cn]);
        end 
    end
end

