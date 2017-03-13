classdef GP
    properties
        train_x;
        train_y;
    end
    
    methods(Static)
        function K = rbf(x, y)
            n1 = size(x, 1);
            n2 = size(y, 1);
            euclidean_dist = zeros(n1, n2);
            for i = 1:n1
                for j = 1:n2
                    euclidean_dist(i, j) = sum((x(i, :) - y(j, :)).^2);
                end;
            end;
            
            gamma = 1;
            K = exp(-gamma * euclidean_dist);
        end
        
        function y = postprocess_y(y)
            n = size(y);
            n = n(1);
            for i=1:n
                arr = y(i, :);
                arr(arr==max(arr)) = 1;
                arr(arr~=max(arr)) = 0;
                y(i, :) = arr;
            end;
        end;
        
        function y = preprocess_y(y)
            n = size(y);
            n = n(1);
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
            y = new_y;
        end;
        
        function X = preprocess_x(X)
            n = size(X);
            n = n(1);
            
            X = (X - repmat(mean(X), n, 1)) ./ repmat(std(X), n, 1);
        end;
    end;
        
    methods
        function obj = train(obj, X, y)
            X = obj.preprocess_x(X);
            y = obj.preprocess_y(y);
            
            obj.train_x = X;
            obj.train_y = y;
        end;

        function [mu_, s_] = predict_(obj, x, clsfr_no)
            K_ = obj.rbf(obj.train_x, obj.train_x);
            K_x = obj.rbf(obj.train_x, x);
            K_xx = obj.rbf(x, x);
            
            m_inv = inv(K_);
            mu_ = K_x' * m_inv * obj.train_y(:, clsfr_no);
            s_ = K_xx - K_x' * m_inv * K_x;
        end
        
        function y = predict(obj, X)
            n = size(X);
            n = n(1);
            X = obj.preprocess_x(X);
            y = zeros(n, 4);
            for i=1:4
                y(1:n, i) = obj.predict_(X, i);
            end;
            y = obj.postprocess_y(y);
        end;
        
        function s = saveobj(obj)
            s.train_x = obj.train_x;
            s.train_y = obj.train_y;
        end;
    end;
end