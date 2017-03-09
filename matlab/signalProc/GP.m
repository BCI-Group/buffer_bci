classdef GP
    properties
        train_x;
        train_y;
        clfrs;
        pre_y;
    end
    
    methods
        function y = postprocess_y(y)
            n = size(y)(1);
            sum_across = sum(y, 2);
            for i=1:n
                arr = sum_across(i);
                arr(arr==max(arr)) = 1;
                arr(arr~=max(arr)) = 0;
                sum_across(i, 1:4) = arr;
            end;
            y = sum_across;
        end;
        
        function y = preprocess_y(obj, y)
            n = size(y)(1);
            new_y = zeros(n, 4);
            for i=1:n
                if strcmp(y(i, 1), 'Left')
                    new_y(i, 1) = 1;
                elseif strcmp(y(i, 1), 'Right')
                    new_y(i, 2) = 1;
                elseif strcmp(y(i, 1), 'Feet')
                    new_y(i, 3) = 1;
                else
                    new_y(i, 4) = 1;
                end;
            end;
        end;
        
        function train(obj, X, y)
            X = obj.preprocess_x(X);
            y = obj.preprocess_y(y);
            
            obj.clfrs = [];
            for i=1:4
                clfr = BaseGP;
                clfr.train_X = X;
                clfr.train_y = y(:, i);
                obj.clfrs(i) = clfr;
            end;
        end;
        
        function y = predict(obj, X)
            n = size(X)(1);
            X = obj.preprocess_x(X);
            y = zeros(n, 4);
            for j=1:4
                clfr_p = obj.clfrs(j);
                y(1:n, j) = clfr_p.predict(X);
            end;
            y = obj.postprocess_y(y);
        end;
    end;
end;