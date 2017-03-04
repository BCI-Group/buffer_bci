classdef GP
    properties
        train_x
        train_y
    end
    
    methods
        function K = rbf(obj, x, y)
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
        
        function [mu_, s_] = predict(obj, x)
            K_ = obj.rbf(obj.train_x, obj.train_x);
            K_x = obj.rbf(obj.train_x, x);
            K_xx = obj.rbf(x, x);
            
            m_inv = inv(K_);
            mu_ = K_x' * m_inv * obj.train_y;
            s_ = K_xx - K_x' * m_inv * K_x;
        end
        
        function update(obj, x, y)
            n = size(obj.train_x, 1);
            obj.train_x(n+1, :) = x;
            obj.train_y(n+1, :) = y;
        end
        
        function s = saveobj(obj)
            s.train_x = obj.train_x;
            s.train_y = obj.train_y;
        end
    end
        methods(Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = GP;
                obj.train_x = s.train_x;
                obj.train_y = s.train_y;
            else
                obj = s;
            end
        end
    end
end