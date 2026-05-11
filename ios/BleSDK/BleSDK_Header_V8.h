//
//  BleSDK_Header.h
//  BleSDK
//
//  Created by yang sai on 2022/4/27.
//

#ifndef BleSDK_Header_V8_h
#define BleSDK_Header_V8_h


typedef NS_ENUM(NSInteger, DATATYPE_V8) {
    GetDeviceTime_V8 = 0,
    SetDeviceTime_V8 = 1,
    GetPersonalInfo_V8 = 2,
    SetPersonalInfo_V8 = 3,
    GetDeviceInfo_V8 = 4,
    SetDeviceInfo_V8 = 5,
    SetDeviceID_V8 = 6,
    GetDeviceGoal_V8 = 7,
    SetDeviceGoal_V8 = 8,
    GetDeviceBattery_V8 = 9,
    GetDeviceMacAddress_V8 = 10,
    GetDeviceVersion_V8 = 11,
    FactoryReset_V8 = 12,
    MCUReset_V8 = 13,
    MotorVibration_V8 = 14,
    GetDeviceName_V8 = 15,
    SetDeviceName_V8 = 16,
    GetAutomaticMonitoring_V8 = 17,
    SetAutomaticMonitoring_V8 = 18,
    GetAlarmClock_V8 = 19,
    SetAlarmClock_V8 = 20,
    DeleteAllAlarmClock_V8 = 21,
    GetSedentaryReminder_V8 = 22,
    SetSedentaryReminder_V8 = 23,
    RealTimeStep_V8 = 24,
    TotalActivityData_V8 = 25,
    DetailActivityData_V8 = 26,
    DetailSleepData_V8 = 27,
    DynamicHR_V8 = 28,
    StaticHR_V8 = 29,
    ActivityModeData_V8 = 30,
    StartActivityMode_V8 = 31,
    StopActivityMode_V8 = 32,
    PauseActivityMode_V8 = 33,
    ContinueActivityMode_V8 = 34,
    GetActivityMode_V8 = 35,
    DeviceSendDataToAPP_V8 = 36,
    EnterTakePhotoMode_V8 = 37,
    StartTakePhoto_V8 = 38,
    StopTakePhoto_V8 = 39,
    BackHomeView_V8 = 40,
    HRVData_V8 = 41,
    GPSData_V8 = 42,
    SetSocialDistanceReminder_V8 = 43,
    GetSocialDistanceReminder_V8 = 44,
    AutomaticSpo2Data_V8 = 45,
    ManualSpo2Data_V8 = 46,
    FindMobilePhone_V8 = 47,
    TemperatureData_V8 = 48,
    AxillaryTemperatureData_V8 = 49,
    SOS_V8  =  50,
    ECG_HistoryData_V8 = 51,
 
    StartECG_V8 = 52,
    StopECG_V8  = 53,
    ECG_RawData_V8 = 54,
    ECG_Success_Result_V8  = 55,
    ECG_Status_V8  = 56,
    ECG_Failed_V8 =  57,
    DeviceMeasurement_HR_V8 =  58,
    DeviceMeasurement_HRV_V8 =  59,
    DeviceMeasurement_Spo2_V8 =  60,
    unLockScreen_V8 = 61,
    lockScreen_V8 = 62,
    clickYesWhenUnLockScreen_V8 = 63,
    clickNoWhenUnLockScreen_V8 = 64,
    setWeather_V8  =  65,
    openRRInterval_V8  =  66,
    closeRRInterval_V8  =  67,
    realtimeRRIntervalData_V8  =  68,
    realtimePPIData_V8  =  69,
    realtimePPGData_V8  =  70,
    ppgStartSucessed_V8 = 71,
    ppgStartFailed_V8 = 72,
    ppgResult_V8 = 73,
    ppgStop_V8 = 74,
    ppgQuit_V8 = 75,
    ppgMeasurementProgress_V8 = 76,
    clearAllHistoryData_V8 = 77,
    setMenstruationInfo_V8 = 78,
    setPregnancyInfo_V8 = 79,
    DeviceMeasurement_V8 =  80,
    DetailSleepAndActivityData_V8 =  81,
    ppiData_V8 = 82,
    
    
    DataError_V8 =  255
};



typedef struct DeviceTime_V8 {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
} MyDeviceTime_V8;

typedef struct PersonalInfo_V8 {
    int gender;
    int age;
    int height;
    int weight;
    int stride;
} MyPersonalInfo_V8;

typedef struct NotificationType_V8 {
    int call;
    int SMS;
    int wechat;
    int facebook;
    int instagram;
    int skype;
    int telegram;
    int twitter;
    int vkclient;
    int whatsapp;
    int qq;
    int In;
} MyNotificationType_V8;

typedef struct DeviceInfo_V8 {
    int distanceUnit;
    int timeUnit;
    int wristOn;
    int temperatureUnit;
    int notDisturbMode;
    int ANCS;
    MyNotificationType_V8 notificationType;
    int baseHeartRate;
    int screenBrightness;
    int watchFaceStyle;
    int socialDistanceRemind;
    int language;
} MyDeviceInfo_V8;




typedef struct Weeks_V8 {
    BOOL sunday;
    BOOL monday;
    BOOL Tuesday;
    BOOL Wednesday;
    BOOL Thursday;
    BOOL Friday;
    BOOL Saturday;
} MyWeeks_V8;


/**
 AutomaticMonitoring
 mode:工作模式，0：关闭  1:时间段工作方式，2： 时间段内间隔工作方式
 startTime_Hour: 开始时间的小时
 startTime_Minutes: 开始时间的分钟
 endTime_Hour:
*/

typedef struct AutomaticMonitoring_V8 {
    int mode;
    int startTime_Hour;
    int startTime_Minutes;
    int endTime_Hour;
    int endTime_Minutes;
    MyWeeks_V8 weeks;
    int intervalTime;
    int dataType;// 1 means heartRate  2 means spo2  3 means temperature  4 means HRV
} MyAutomaticMonitoring_V8;




typedef struct BPCalibrationParameter_V8 {
    int gender;
    int age;
    int height;
    int weight;
    int BP_high;
    int BP_low;
    int heartRate;
} MyBPCalibrationParameter_V8;


typedef struct WeatherParameter_V8 {
    int weatherType;
    int currentTemperature;
    int highestTemperature;
    int lowestTemperature;
    NSString * strCity;
} MyWeatherParameter_V8;

typedef struct BreathParameter_V8 {
    int breathMode; //  0  1  2 three mode 
    int DurationOfBreathingExercise;
} MyBreathParameter_V8;

typedef struct SocialDistanceReminder_V8 {
    char scanInterval;
    char scanTime;
    char signalStrength;
} MySocialDistanceReminder_V8;


typedef NS_ENUM(NSInteger, MeasurementDataType_V8) {
    heartRateData_V8    = 2,
    spo2Data_V8 = 3,
    hrvData_v8 = 4
};

typedef NS_ENUM(NSInteger, ACTIVITYMODE_V8) {
    Run = 0,
    Cycling    = 1,
    Badminton = 2,
    Football    = 3,
    Tennis = 4,
    Yoga    = 5,
    Breath = 6,
    Dance    = 7,
    Basketball = 8,
    Walk    = 9,
    Workout    = 10,
    Cricket    = 11,
    Hiking    = 12,
    Aerobics    = 13,
    PingPong    = 14,
    RopeJump    = 15,
    SitUps    = 16,
    Volleyball    = 17
};

typedef NS_ENUM(NSInteger, WORKMODE_V8) {
    startActivity = 1,
    pauseActivity    = 2,
    continueActivity = 3,
    stopActivity    = 4
};


#endif /* BleSDK_Header_V8_h */
