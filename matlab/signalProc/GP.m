classdef GP
    properties
        train_x;
        train_y;
        indexes;
        coefs;
        d;
        mean_train;
        std_train;
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

        function K_linear = linear(x, y)
            n1 = size(x, 1);
            n2 = size(y, 1);
            linear_dist = zeros(n1, n2);
            for i = 1:n1
                for j = 1:n2
                    linear_dist(i, j) = sum((x(i, :) - y(j, :)).^2);
                end;
            end;
            K_linear = linear_dist;
        end;
            
        function y = postprocess_y(y)
            n = size(y, 1);
            for j=1:2
                for i=1:n
                    arr = y(i, :);
                    arr(arr==max(arr)) = 1;
                    arr(arr~=max(arr)) = 0;
                    y(i, :) = arr;
                end;
            end;
        end;

        function y = preprocess_y(y)
            n = size(y);
            n = n(1);
            new_y = zeros(n, 4);
            for i=1:n
                if strcmp(y(i, 1), '2 Left-Hand ')
                    new_y(i, 1) = 1;
                elseif strcmp(y(i, 1), '3 Right-Hand ')
                    new_y(i, 2) = 1;
                elseif strcmp(y(i, 1), '1 Feet ')
                    new_y(i, 3) = 1;
                else
                    new_y(i, 4) = 1;
                end;
            end;
            y = new_y;
        end;

        function [X, indexes, coefs, d, mean_train, std_train] = preprocess_x(X, indexes, coefs, d, mean_train, std_train)
            n = size(X);
            n = n(1);

            if ~indexes
%                 indexes = any(isnan(X));
%                 X(:, indexes) = [];
                
                [coefs, scores, variances] = princomp(X, 'econ');
                pervar = 100*cumsum(variances) / sum(variances);
%                 d = max(find(pervar < 90));
                d = 4;
                X = X(:, 1:d);
                
                mean_train = mean(X);
                std_train = std(X);
                X = (X - repmat(mean_train, n, 1)) ./ repmat(std_train, n, 1);
            else
                X = X*coefs(:, 1:d);
                X = (X - repmat(mean_train, n, 1)) ./ repmat(std_train, n, 1);
            end;
        end;

        function acc = accuracy(predicted, true)
            n = size(predicted);
            n = n(1);
            
            predicted(predicted > 0) = 1;
            for i=2:4
                predicted(predicted(:, i) == 1) = i;
                true(true(:, i) == 1) = i;
            end;
            predicted = predicted(:, 1);
            true = true(:, 1);
            acc = sum(predicted == true) / n;
        end;
    end;

    methods
        function classifier = train(obj, X, y)
            [X, indexes, coefs, d, mean_train, std_train] = obj.preprocess_x(X, false);
            y = obj.preprocess_y(y);
            
            obj.train_x = X;
            obj.train_y = y;
            obj.indexes = indexes;
            obj.coefs = coefs;
            obj.d = d;
            obj.mean_train = mean_train;
            obj.std_train = std_train;
            
            classifier = struct('train_x', X, 'train_y', y, 'indexes', indexes, 'coefs', coefs, 'd', d, 'mean_train', mean_train, 'std_train', std_train);
        end;

        function [mu_, s_] = predict_(obj, x, clsfr_no)
            K_ = obj.linear(obj.train_x, obj.train_x);
            K_x = obj.linear(obj.train_x, x);
            K_xx = obj.linear(x, x);
            
            m_inv = inv(K_);
            mu_ = K_x' * m_inv * obj.train_y(:, clsfr_no);
            s_ = K_xx - K_x' * m_inv * K_x;
        end
        
        function y = predict(obj, X)
            n = size(X, 1);
            X = obj.preprocess_x(X, obj.indexes, obj.coefs, obj.d, obj.mean_train, obj.std_train);
            y = zeros(n, 4);
            for i=1:4
                y(1:n, i) = obj.predict_(X, i);
            end;
            y = obj.postprocess_y(y);
        end;

        function update(obj, x, y)
            n = size(obj.train_x, 1);
            obj.train_x(n+1, :) = x;
            obj.train_y(n+1, :) = y;
        end
        
        function s = saveobj(obj)
            s.train_x = obj.train_x;
            s.train_y = obj.train_y;
        end;
    end;
end