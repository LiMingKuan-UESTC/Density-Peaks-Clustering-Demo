% Copyright 2026 LI MingKuan
%
% 原项目：Density-Peaks-Clustering-Demo
% 作者：LiMingKuan-UESTC
% 仓库地址：https://github.com/LiMingKuan-UESTC/Density-Peaks-Clustering-Demo

function demo(varargin)

clc;
% 非 GUI 自检模式：便于检查核心算法是否正常工作。
if nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'selftest')
    runSelfTest();
    return;
end

%% 1. 默认数据
rng(7);

X = [
    randn(10, 2) * 0.28 + [1.2, 1.2];
    randn(10, 2) * 0.32 + [4.2, 1.4];
    randn(10, 2) * 0.30 + [2.6, 3.8];
    randn(4,  2) * 0.20 + [4.0, 3.4]
];

n = size(X, 1);

K = 3;              % 默认聚类中心数
dcPercent = 2.0;    % 默认截断距离百分位
currentFrame = 1;
isPlaying = false;
autoTimer = [];

model = computeDPC(X, K, dcPercent);

%% 2. 创建界面
fig = figure( ...
    'Name', 'Density Peaks Clustering Demo', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [100, 80, 1200, 680], ...
    'CloseRequestFcn', @closeFigure);

axMain = axes('Parent', fig, 'Position', [0.06, 0.18, 0.50, 0.72]);
axSide = axes('Parent', fig, 'Position', [0.62, 0.30, 0.33, 0.52]);

infoBox = uicontrol( ...
    'Parent', fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.62, 0.08, 0.33, 0.16], ...
    'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11, ...
    'String', '');

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '上一步', ...
    'Units', 'normalized', ...
    'Position', [0.06, 0.06, 0.08, 0.06], ...
    'FontSize', 11, ...
    'Callback', @prevFrame);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '下一步', ...
    'Units', 'normalized', ...
    'Position', [0.15, 0.06, 0.08, 0.06], ...
    'FontSize', 11, ...
    'Callback', @nextFrame);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '自动播放', ...
    'Units', 'normalized', ...
    'Position', [0.24, 0.06, 0.09, 0.06], ...
    'FontSize', 11, ...
    'Callback', @playAuto);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '暂停', ...
    'Units', 'normalized', ...
    'Position', [0.34, 0.06, 0.07, 0.06], ...
    'FontSize', 11, ...
    'Callback', @pauseAuto);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '重置', ...
    'Units', 'normalized', ...
    'Position', [0.42, 0.06, 0.07, 0.06], ...
    'FontSize', 11, ...
    'Callback', @resetDemo);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'text', ...
    'String', 'K:', ...
    'Units', 'normalized', ...
    'Position', [0.51, 0.075, 0.025, 0.03], ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

editK = uicontrol( ...
    'Parent', fig, ...
    'Style', 'edit', ...
    'String', num2str(K), ...
    'Units', 'normalized', ...
    'Position', [0.535, 0.065, 0.045, 0.05], ...
    'FontSize', 11);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'text', ...
    'String', 'dc%:', ...
    'Units', 'normalized', ...
    'Position', [0.59, 0.075, 0.04, 0.03], ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

editDc = uicontrol( ...
    'Parent', fig, ...
    'Style', 'edit', ...
    'String', num2str(dcPercent), ...
    'Units', 'normalized', ...
    'Position', [0.635, 0.065, 0.055, 0.05], ...
    'FontSize', 11);

uicontrol( ...
    'Parent', fig, ...
    'Style', 'pushbutton', ...
    'String', '重新计算', ...
    'Units', 'normalized', ...
    'Position', [0.705, 0.06, 0.09, 0.06], ...
    'FontSize', 11, ...
    'Callback', @recomputeDemo);

renderFrame();

%% 3. 交互回调

    function prevFrame(varargin)
        pauseAuto();
        currentFrame = max(1, currentFrame - 1);
        renderFrame();
    end

    function nextFrame(varargin)
        totalFrames = getTotalFrames();
        currentFrame = min(totalFrames, currentFrame + 1);
        renderFrame();

        if currentFrame >= totalFrames
            pauseAuto();
        end
    end

    function playAuto(varargin)
        if isPlaying
            return;
        end

        isPlaying = true;

        autoTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', 0.9, ...
            'TimerFcn', @(~, ~) autoStep());

        start(autoTimer);
    end

    function autoStep()
        if ~ishandle(fig)
            return;
        end

        totalFrames = getTotalFrames();

        if currentFrame < totalFrames
            currentFrame = currentFrame + 1;
            renderFrame();
        else
            pauseAuto();
        end
    end

    function pauseAuto(varargin)
        isPlaying = false;

        if ~isempty(autoTimer)
            try
                stop(autoTimer);
                delete(autoTimer);
            catch
            end
            autoTimer = [];
        end
    end

    function resetDemo(varargin)
        pauseAuto();
        currentFrame = 1;
        renderFrame();
    end

    function recomputeDemo(varargin)
        pauseAuto();

        newK = str2double(get(editK, 'String'));
        newDcPercent = str2double(get(editDc, 'String'));

        if isnan(newK) || newK < 1
            newK = 3;
        end

        if isnan(newDcPercent) || newDcPercent <= 0 || newDcPercent >= 50
            newDcPercent = 2.0;
        end

        K = round(newK);
        K = min(max(K, 1), n);

        dcPercent = newDcPercent;

        set(editK, 'String', num2str(K));
        set(editDc, 'String', num2str(dcPercent));

        model = computeDPC(X, K, dcPercent);
        currentFrame = 1;

        renderFrame();
    end

    function closeFigure(varargin)
        pauseAuto();
        delete(fig);
    end

%% 4. 绘图主函数

    function renderFrame()
        if ~ishandle(fig)
            return;
        end

        clearColorbars();

        cla(axMain);
        cla(axSide);

        set(axMain, 'Visible', 'on');
        set(axSide, 'Visible', 'on');

        hold(axMain, 'on');
        hold(axSide, 'on');

        grid(axMain, 'on');
        grid(axSide, 'on');

        axis(axMain, 'equal');

        xlim(axMain, [min(X(:, 1)) - 0.8, max(X(:, 1)) + 0.8]);
        ylim(axMain, [min(X(:, 2)) - 0.8, max(X(:, 2)) + 0.8]);

        totalFrames = getTotalFrames();

        if currentFrame == 1
            drawRawData();

        elseif currentFrame == 2
            drawCutoffDistance();

        elseif currentFrame == 3
            drawLocalDensity();

        elseif currentFrame == 4
            drawDeltaDistance();

        elseif currentFrame == 5
            drawDecisionGraph();

        elseif currentFrame == 6
            drawCenters();

        else
            assignStep = currentFrame - 7;
            drawAssignment(assignStep);
        end

        set(infoBox, 'String', getInfoText(currentFrame, totalFrames));
    end

%% 5. 各阶段绘图

    function drawRawData()
        scatter(axMain, X(:, 1), X(:, 2), 70, ...
            'MarkerFaceColor', [0.35, 0.55, 0.90], ...
            'MarkerEdgeColor', 'k');

        addPointLabels(axMain);

        title(axMain, 'Step 1：原始样本点', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        text(axSide, 0.05, 0.85, '密度峰值聚类 DPC', ...
            'Units', 'normalized', ...
            'FontSize', 15, ...
            'FontWeight', 'bold');

        text(axSide, 0.05, 0.65, ...
            sprintf(['核心思想：\n\n', ...
            '1. 聚类中心通常具有较高局部密度 rho\n', ...
            '2. 聚类中心远离其他更高密度点，即 delta 较大\n', ...
            '3. 通过 rho-delta 决策图选择中心\n', ...
            '4. 其他样本归属到最近的更高密度邻居']), ...
            'Units', 'normalized', ...
            'FontSize', 11);

        axis(axSide, 'off');
    end

    function drawCutoffDistance()
        scatter(axMain, X(:, 1), X(:, 2), 70, ...
            'MarkerFaceColor', [0.80, 0.85, 0.95], ...
            'MarkerEdgeColor', 'k');

        addPointLabels(axMain);

        [~, rhoOrder] = sort(model.rho, 'descend');
        showIdx = rhoOrder(1:min(4, n));

        for i = 1:length(showIdx)
            p = showIdx(i);
            drawCircle(axMain, X(p, 1), X(p, 2), model.dc);
        end

        title(axMain, 'Step 2：截断距离 dc 与邻域范围', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        imagesc(axSide, model.D);
        axis(axSide, 'image');
        title(axSide, '样本距离矩阵', 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(axSide, '样本编号');
        ylabel(axSide, '样本编号');

        cb = colorbar(axSide);
        cb.Label.String = 'Distance';
    end

    function drawLocalDensity()
        rhoSize = 60 + 260 * normalize01(model.rho);

        scatter(axMain, X(:, 1), X(:, 2), rhoSize, model.rho, ...
            'filled', ...
            'MarkerEdgeColor', 'k');

        addPointLabels(axMain);

        title(axMain, 'Step 3：计算局部密度 \rho', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        cb = colorbar(axMain);
        cb.Label.String = '\rho';

        [rhoSorted, order] = sort(model.rho, 'descend');

        bar(axSide, rhoSorted);
        title(axSide, '局部密度 \rho 排序', 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(axSide, '密度排名');
        ylabel(axSide, '\rho');

        for i = 1:length(order)
            text(axSide, i, rhoSorted(i), num2str(order(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 8);
        end
    end

    function drawDeltaDistance()
        scatter(axMain, X(:, 1), X(:, 2), 70, ...
            'MarkerFaceColor', [0.90, 0.90, 0.90], ...
            'MarkerEdgeColor', 'k');

        addPointLabels(axMain);

        for i = 1:n
            j = model.nneigh(i);
            if j > 0
                plot(axMain, [X(i, 1), X(j, 1)], [X(i, 2), X(j, 2)], ...
                    '--', ...
                    'Color', [0.55, 0.55, 0.55], ...
                    'LineWidth', 0.8);
            end
        end

        deltaSize = 60 + 260 * normalize01(model.delta);

        scatter(axMain, X(:, 1), X(:, 2), deltaSize, model.delta, ...
            'filled', ...
            'MarkerEdgeColor', 'k');

        title(axMain, 'Step 4：计算相对距离 \delta', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        cb = colorbar(axMain);
        cb.Label.String = '\delta';

        [deltaSorted, order] = sort(model.delta, 'descend');

        bar(axSide, deltaSorted);
        title(axSide, '相对距离 \delta 排序', 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(axSide, '\delta 排名');
        ylabel(axSide, '\delta');

        for i = 1:length(order)
            text(axSide, i, deltaSorted(i), num2str(order(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 8);
        end
    end

    function drawDecisionGraph()
        scatter(axMain, X(:, 1), X(:, 2), 70, ...
            'MarkerFaceColor', [0.80, 0.85, 0.95], ...
            'MarkerEdgeColor', 'k');

        addPointLabels(axMain);

        title(axMain, 'Step 5：构造 \rho-\delta 决策图', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        drawDecisionGraphBase(false);

        title(axSide, '决策图：横轴 \rho，纵轴 \delta', 'FontSize', 13, 'FontWeight', 'bold');
    end

    function drawCenters()
        colors = lines(K);

        scatter(axMain, X(:, 1), X(:, 2), 70, ...
            'MarkerFaceColor', [0.88, 0.88, 0.88], ...
            'MarkerEdgeColor', 'k');

        for c = 1:K
            p = model.centers(c);
            scatter(axMain, X(p, 1), X(p, 2), 230, colors(c, :), ...
                'filled', ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.5);

            text(axMain, X(p, 1), X(p, 2) + 0.22, ...
                sprintf('Center %d', c), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 10, ...
                'FontWeight', 'bold');
        end

        addPointLabels(axMain);

        title(axMain, 'Step 6：选择聚类中心', 'FontSize', 14, 'FontWeight', 'bold');
        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        drawDecisionGraphBase(true);
        title(axSide, '根据 \gamma = \rho \times \delta 选择中心', ...
            'FontSize', 13, 'FontWeight', 'bold');
    end

    function drawAssignment(assignStep)
        colors = lines(K);

        partialLabels = zeros(n, 1);

        for c = 1:K
            partialLabels(model.centers(c)) = c;
        end

        assignOrder = model.assignOrder;
        assignStep = max(0, min(assignStep, length(assignOrder)));

        for t = 1:assignStep
            p = assignOrder(t);
            parent = model.nneigh(p);

            if parent > 0 && partialLabels(parent) > 0
                partialLabels(p) = partialLabels(parent);
            else
                [~, nearestCenter] = min(model.D(p, model.centers));
                partialLabels(p) = nearestCenter;
            end
        end

        unassigned = partialLabels == 0;

        if any(unassigned)
            scatter(axMain, X(unassigned, 1), X(unassigned, 2), 55, ...
                'MarkerFaceColor', [0.85, 0.85, 0.85], ...
                'MarkerEdgeColor', [0.35, 0.35, 0.35]);
        end

        for c = 1:K
            idx = partialLabels == c;

            if any(idx)
                scatter(axMain, X(idx, 1), X(idx, 2), 85, colors(c, :), ...
                    'filled', ...
                    'MarkerEdgeColor', 'k');
            end
        end

        for c = 1:K
            p = model.centers(c);
            scatter(axMain, X(p, 1), X(p, 2), 260, colors(c, :), ...
                'p', ...
                'filled', ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.5);
        end

        if assignStep > 0 && assignStep <= length(assignOrder)
            p = assignOrder(assignStep);
            parent = model.nneigh(p);

            scatter(axMain, X(p, 1), X(p, 2), 210, ...
                'o', ...
                'MarkerEdgeColor', 'r', ...
                'LineWidth', 2.0);

            if parent > 0
                plot(axMain, [X(p, 1), X(parent, 1)], [X(p, 2), X(parent, 2)], ...
                    'r--', ...
                    'LineWidth', 1.6);
            end
        end

        addPointLabels(axMain);

        title(axMain, sprintf('Step 7：样本逐步归属，进度 %d / %d', ...
            assignStep, length(assignOrder)), ...
            'FontSize', 14, ...
            'FontWeight', 'bold');

        xlabel(axMain, 'x_1');
        ylabel(axMain, 'x_2');

        drawDecisionGraphBase(true);

        title(axSide, '聚类中心与样本分配过程', ...
            'FontSize', 13, ...
            'FontWeight', 'bold');
    end

%% 6. 通用辅助绘图函数

    function drawDecisionGraphBase(showCenters)
        gammaSize = 50 + 260 * normalize01(model.gamma);

        scatter(axSide, model.rho, model.delta, gammaSize, model.gamma, ...
            'filled', ...
            'MarkerEdgeColor', 'k');

        xlabel(axSide, '\rho');
        ylabel(axSide, '\delta');

        cb = colorbar(axSide);
        cb.Label.String = '\gamma = \rho \times \delta';

        for i = 1:n
            text(axSide, model.rho(i), model.delta(i), ['  ', num2str(i)], ...
                'FontSize', 8);
        end

        if showCenters
            colors = lines(K);

            for c = 1:K
                p = model.centers(c);

                scatter(axSide, model.rho(p), model.delta(p), 260, colors(c, :), ...
                    'p', ...
                    'filled', ...
                    'MarkerEdgeColor', 'k', ...
                    'LineWidth', 1.5);

                text(axSide, model.rho(p), model.delta(p), ...
                    sprintf('  Center %d', c), ...
                    'FontSize', 10, ...
                    'FontWeight', 'bold');
            end
        end
    end

    function drawCircle(ax, cx, cy, r)
        theta = linspace(0, 2 * pi, 120);
        plot(ax, cx + r * cos(theta), cy + r * sin(theta), ...
            '--', ...
            'Color', [0.2, 0.2, 0.2], ...
            'LineWidth', 1.1);
    end

    function addPointLabels(ax)
        for i = 1:n
            text(ax, X(i, 1) + 0.04, X(i, 2) + 0.04, num2str(i), ...
                'FontSize', 8, ...
                'Color', [0.15, 0.15, 0.15]);
        end
    end

    function clearColorbars()
        try
            delete(findall(fig, 'Type', 'colorbar'));
        catch
        end

        try
            delete(findall(fig, 'Tag', 'Colorbar'));
        catch
        end
    end

%% 7. 信息说明

    function txt = getInfoText(frame, totalFrames)
        if frame == 1
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：原始数据展示\n\n', ...
                'DPC 的目标是寻找同时满足两个特征的点：\n', ...
                '1. 局部密度较高\n', ...
                '2. 距离其他更高密度点较远'], frame, totalFrames);

        elseif frame == 2
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：截断距离 dc\n\n', ...
                'dc 由所有样本间距离的 %.2f%% 分位数确定。\n', ...
                '当前 dc = %.4f'], ...
                frame, totalFrames, dcPercent, model.dc);

        elseif frame == 3
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：局部密度 rho\n\n', ...
                'rho 越大，说明该点附近样本越密集。\n', ...
                '本 Demo 使用 Gaussian kernel 计算局部密度。'], frame, totalFrames);

        elseif frame == 4
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：相对距离 delta\n\n', ...
                'delta 表示该点到更高密度点的最近距离。\n', ...
                '聚类中心通常具有较大的 rho 和较大的 delta。'], frame, totalFrames);

        elseif frame == 5
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：rho-delta 决策图\n\n', ...
                '右图中靠右上方的点更可能成为聚类中心。\n', ...
                '这里使用 gamma = rho × delta 进行排序。'], frame, totalFrames);

        elseif frame == 6
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：选择聚类中心\n\n', ...
                '当前 K = %d。\n', ...
                '选择 gamma 最大的 K 个点作为聚类中心。'], frame, totalFrames, K);

        else
            assignStep = frame - 7;
            txt = sprintf([ ...
                'Frame %d / %d\n', ...
                '当前阶段：样本分配\n\n', ...
                '非中心点按照局部密度从高到低依次分配。\n', ...
                '每个点归属到最近的更高密度邻居所在的簇。\n\n', ...
                '分配进度：%d / %d'], ...
                frame, totalFrames, ...
                max(0, min(assignStep, length(model.assignOrder))), ...
                length(model.assignOrder));
        end
    end

    function totalFrames = getTotalFrames()
        totalFrames = 7 + length(model.assignOrder);
    end

%% 8. DPC 核心算法

    function result = computeDPC(Xin, k, dcPct)
        N = size(Xin, 1);
        k = min(max(round(k), 1), N);

        D = computeDistanceMatrix(Xin);

        upperMask = triu(true(N), 1);
        allDist = D(upperMask);
        allDist = sort(allDist(:));

        idx = round(length(allDist) * dcPct / 100);
        idx = max(1, min(idx, length(allDist)));

        dc = allDist(idx);

        if dc <= 0 || isnan(dc)
            dc = median(allDist);
        end

        if dc <= 0 || isnan(dc)
            dc = 1;
        end

        % Gaussian kernel 局部密度。
        % rho 越大，说明该点附近的样本越密集。
        rho = sum(exp(-(D ./ dc) .^ 2), 2) - 1;

        [~, rhoOrder] = sort(rho, 'descend');

        delta = zeros(N, 1);
        nneigh = zeros(N, 1);

        for ii = 1:N
            p = rhoOrder(ii);

            if ii == 1
                delta(p) = max(D(p, :));
                nneigh(p) = 0;
            else
                higherPoints = rhoOrder(1:ii - 1);
                [delta(p), minIdx] = min(D(p, higherPoints));
                nneigh(p) = higherPoints(minIdx);
            end
        end

        gamma = rho .* delta;

        [~, gammaOrder] = sort(gamma, 'descend');
        centers = gammaOrder(1:k);

        labels = zeros(N, 1);

        for c = 1:k
            labels(centers(c)) = c;
        end

        assignOrder = rhoOrder(~ismember(rhoOrder, centers));

        for ii = 1:length(assignOrder)
            p = assignOrder(ii);
            parent = nneigh(p);

            if parent > 0 && labels(parent) > 0
                labels(p) = labels(parent);
            else
                [~, nearestCenter] = min(D(p, centers));
                labels(p) = nearestCenter;
            end
        end

        result.D = D;
        result.dc = dc;
        result.rho = rho;
        result.delta = delta;
        result.gamma = gamma;
        result.nneigh = nneigh;
        result.centers = centers;
        result.labels = labels;
        result.assignOrder = assignOrder;
        result.rhoOrder = rhoOrder;
    end

    function D = computeDistanceMatrix(Xin)
        sq = sum(Xin .^ 2, 2);
        D2 = sq + sq' - 2 * (Xin * Xin');
        D2(D2 < 0) = 0;
        D = sqrt(D2);
        D(1:size(D, 1) + 1:end) = 0;
    end

    function y = normalize01(x)
        x = x(:);
        xmin = min(x);
        xmax = max(x);

        if abs(xmax - xmin) < eps
            y = ones(size(x));
        else
            y = (x - xmin) ./ (xmax - xmin);
        end
    end

%% 9. 自检函数

    function runSelfTest()
        rng(7);

        Xtest = [
            randn(10, 2) * 0.28 + [1.2, 1.2];
            randn(10, 2) * 0.32 + [4.2, 1.4];
            randn(10, 2) * 0.30 + [2.6, 3.8];
            randn(4,  2) * 0.20 + [4.0, 3.4]
        ];

        ktest = 3;
        dcPctTest = 2.0;
        result = computeDPC(Xtest, ktest, dcPctTest);

        Ntest = size(Xtest, 1);

        assert(size(result.D, 1) == Ntest && size(result.D, 2) == Ntest, ...
            'Distance matrix size is incorrect.');
        assert(all(abs(diag(result.D)) < 1e-10), ...
            'Distance matrix diagonal should be zero.');
        assert(norm(result.D - result.D', 'fro') < 1e-10, ...
            'Distance matrix should be symmetric.');
        assert(length(result.rho) == Ntest, ...
            'rho length is incorrect.');
        assert(length(result.delta) == Ntest, ...
            'delta length is incorrect.');
        assert(length(result.gamma) == Ntest, ...
            'gamma length is incorrect.');
        assert(length(result.centers) == ktest, ...
            'center count is incorrect.');
        assert(all(result.labels >= 1 & result.labels <= ktest), ...
            'all samples should be assigned to valid clusters.');
        assert(length(result.assignOrder) == Ntest - ktest, ...
            'assignment order length is incorrect.');

        fprintf('demo_dpc selftest passed.\n');
        fprintf('Sample count: %d\n', Ntest);
        fprintf('K: %d\n', ktest);
        fprintf('dc: %.6f\n', result.dc);
        fprintf('Centers: %s\n', mat2str(result.centers(:)'));
        fprintf('Cluster labels: %s\n', mat2str(result.labels(:)'));
    end

end
