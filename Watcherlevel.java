public class WaterLevel {
    private double currentLevel;
    private double warningLevel;
    private double dangerLevel;

    public WaterLevel() {
    }

    public WaterLevel(double currentLevel, double warningLevel, double dangerLevel) {
        this.currentLevel = currentLevel;
        this.warningLevel = warningLevel;
        this.dangerLevel = dangerLevel;
    }

    public String getWaterStatus() {
        if (currentLevel >= dangerLevel) {
            return "危险";
        } else if (currentLevel >= warningLevel) {
            return "预警";
        } else {
            return "正常";
        }
    }

    public double calcWarningDiff() {
        return currentLevel - warningLevel;
    }

    public double getCurrentLevel() {
        return currentLevel;
    }

    public void setCurrentLevel(double currentLevel) {
        this.currentLevel = currentLevel;
    }

    public double getWarningLevel() {
        return warningLevel;
    }

    public void setWarningLevel(double warningLevel) {
        this.warningLevel = warningLevel;
    }

    public double getDangerLevel() {
        return dangerLevel;
    }

    public void setDangerLevel(double dangerLevel) {
        this.dangerLevel = dangerLevel;
    }

    public static void main(String[] args) {
        WaterLevel water = new WaterLevel(28.5, 27.0, 30.0);
        System.out.println("当前水位：" + water.getCurrentLevel() + "米");
        System.out.println("水位状态：" + water.getWaterStatus());
        System.out.println("与警戒水位差值：" + water.calcWarningDiff() + "米");
    }
}

