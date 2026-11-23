function cfg = calligraphy_config(character)
%CALLIGRAPHY_CONFIG 离线示例参数。标定前不可视为实机参数。
if nargin < 1, character = '人'; end
cfg.version = 1;
cfg.character = char(character);
cfg.squareSizeMm = 100;
cfg.charactersPerRow = 3;  % 横排，每行最多三个字
cfg.characterGapMm = 30;  % 字框边缘间距，行间距也采用此值
cfg.marginMm = 0;
cfg.Ts = 0.001;
cfg.writeSpeed = 200;       % mm/s，峰值限制
cfg.travelSpeed = 200;
cfg.verticalSpeed = 250;
cfg.cartAcceleration = 200;
cfg.verticalAcceleration = 200;
cfg.liftHeight = 6;
cfg.maxDepth = 8;
cfg.depthProgress = [0 .2 .4 .6 .8 1];
cfg.depthDefault = [0 .8 1.2 1.2 .6 0];
cfg.depthProfiles = {};   % 每笔一个 6x2 [progress, depth_mm]
cfg.paperOrigin = [500 0 602]; % 整段文字排版外框中心，基坐标系 mm
% 安全起点/终点自动取基坐标 [370, 0, paperOrigin(3)+100] mm。
cfg.paperRpyDeg = [0 0 90]; % 字的右方 -> 基坐标 +Y，字的下方 -> 基坐标 +X
cfg.brushRpyDeg = [180 0 0]; % 笔尖坐标系相对纸面，笔杆朝下
cfg.toolOffsetMm = [0 0 0]; % 实验四模型末端 -> 未受压笔尖；待标定
cfg.toolRpyDeg = [0 0 0];
cfg.qSeedDeg = [0 -20 120 0 80 0]; % 仅逆解种子，不代表自动从该位姿移动
cfg.jointSpeedDeg = repmat(180,1,6); % 实验四 3000 rpm / 100
cfg.jointAccelDeg = repmat(80,1,6);
cfg.jointLimitsDeg = [-170 170;-120 120;-140 140;-170 170;-120 120;-360 360];
cfg.calibrated = false;
cfg.geometryToleranceMm = .001;
cfg.strokeSmoothingToleranceMm = .05; % 整笔平滑相对原中心线的采样偏差上限
cfg.maxSamples = 1000000;
cfg.maxTimeScalingIterations = 12;
end
