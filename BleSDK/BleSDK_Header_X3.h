//
//  BleSDK_Header.h
//  BleSDK
//
//  Created by yang sai on 2022/4/27.
//

#ifndef BleSDK_Header_X3_h
#define BleSDK_Header_X3_h


typedef NS_ENUM(NSInteger, DATATYPE_X3) {
    GetDeviceTime_X3 = 0,
    SetDeviceTime_X3 = 1,
    GetPersonalInfo_X3 = 2,
    SetPersonalInfo_X3 = 3,
    GetDeviceInfo_X3 = 4,
    SetDeviceInfo_X3 = 5,
    SetDeviceID_X3 = 6,
    GetDeviceGoal_X3 = 7,
    SetDeviceGoal_X3 = 8,
    GetDeviceBattery_X3 = 9,
    GetDeviceMacAddress_X3 = 10,
    GetDeviceVersion_X3 = 11,
    FactoryReset_X3 = 12,
    MCUReset_X3 = 13,
    MotorVibration_X3 = 14,
    GetDeviceName_X3 = 15,
    SetDeviceName_X3 = 16,
    GetAutomaticMonitoring_X3 = 17,
    SetAutomaticMonitoring_X3 = 18,
    GetAlarmClock_X3 = 19,
    SetAlarmClock_X3 = 20,
    DeleteAllAlarmClock_X3 = 21,
    GetSedentaryReminder_X3 = 22,
    SetSedentaryReminder_X3 = 23,
    RealTimeStep_X3 = 24,
    TotalActivityData_X3 = 25,
    DetailActivityData_X3 = 26,
    DetailSleepData_X3 = 27,
    DynamicHR_X3 = 28,
    StaticHR_X3 = 29,
    ActivityModeData_X3 = 30,
    StartActivityMode_X3 = 31,
    StopActivityMode_X3 = 32,
    PauseActivityMode_X3 = 33,
    ContinueActivityMode_X3 = 34,
    GetActivityMode_X3 = 35,
    DeviceSendDataToAPP_X3 = 36,
    EnterTakePhotoMode_X3 = 37,
    StartTakePhoto_X3 = 38,
    StopTakePhoto_X3 = 39,
    BackHomeView_X3 = 40,
    HRVData_X3 = 41,
    GPSData_X3 = 42,
    SetSocialDistanceReminder_X3 = 43,
    GetSocialDistanceReminder_X3 = 44,
    AutomaticSpo2Data_X3 = 45,
    ManualSpo2Data_X3 = 46,
    FindMobilePhone_X3 = 47,
    TemperatureData_X3 = 48,
    AxillaryTemperatureData_X3 = 49,
    SOS_X3  =  50,
    ECG_HistoryData_X3 = 51,
 
    StartECG_X3 = 52,
    StopECG_X3  = 53,
    ECG_RawData_X3 = 54,
    ECG_Success_Result_X3  = 55,
    ECG_Status_X3  = 56,
    ECG_Failed_X3 =  57,
    DeviceMeasurement_HR_X3 =  58,
    DeviceMeasurement_HRV_X3 =  59,
    DeviceMeasurement_Spo2_X3 =  60,
    unLockScreen_X3 = 61,
    lockScreen_X3 = 62,
    clickYesWhenUnLockScreen_X3 = 63,
    clickNoWhenUnLockScreen_X3 = 64,
    setWeather_X3  =  65,
    openRRInterval_X3  =  66,
    closeRRInterval_X3  =  67,
    realtimeRRIntervalData_X3  =  68,
    realtimePPIData_X3  =  69,
    realtimePPGData_X3  =  70,
    ppgStartSucessed_X3 = 71,
    ppgStartFailed_X3 = 72,
    ppgResult_X3 = 73,
    ppgStop_X3 = 74,
    ppgQuit_X3 = 75,
    ppgMeasurementProgress_X3 = 76,
    clearAllHistoryData_X3 = 77,
    setMenstruationInfo_X3 = 78,
    setPregnancyInfo_X3 = 79,
    DeviceMeasurement_X3 =  80,
    ppiData_X3 = 81,
    sleepAndAcitivityData_X3 = 82,
    eovData_X3 = 83,
    osaData_X3 = 84,
    sleepHrvData_X3 = 85,
    osaFunctionSet_X3 = 86,
    osaFunctionGet_X3 = 87,
    
    DataError_X3 =  255
};



typedef struct DeviceTime_X3 {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
} MyDeviceTime_X3;

typedef struct PersonalInfo_X3 {
    int gender;
    int age;
    int height;
    int weight;
    int stride;
} MyPersonalInfo_X3;

typedef struct NotificationType_X3 {
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
} MyNotificationType_X3;

typedef struct DeviceInfo_X3 {
    NSInteger handPosition;     // 0=左手, 1=右手
    BOOL autoDetectMotion;      // 是否自动检测运动
} MyDeviceInfo_X3;




typedef struct Weeks_X3 {
    BOOL sunday;
    BOOL monday;
    BOOL Tuesday;
    BOOL Wednesday;
    BOOL Thursday;
    BOOL Friday;
    BOOL Saturday;
} MyWeeks_X3;


/**
 AutomaticMonitoring
 mode:工作模式，0：关闭  1:时间段工作方式，2： 时间段内间隔工作方式
 startTime_Hour: 开始时间的小时
 startTime_Minutes: 开始时间的分钟
 endTime_Hour:
*/

typedef struct AutomaticMonitoring_X3 {
    int mode;
    int startTime_Hour;
    int startTime_Minutes;
    int endTime_Hour;
    int endTime_Minutes;
    MyWeeks_X3 weeks;
    int intervalTime;
    int dataType;// 1 means heartRate  2 means spo2  3 means temperature  4 means HRV
} MyAutomaticMonitoring_X3;





typedef struct BPCalibrationParameter_X3 {
    int gender;
    int age;
    int height;
    int weight;
    int BP_high;
    int BP_low;
    int heartRate;
} MyBPCalibrationParameter_X3;


typedef struct WeatherParameter_X3 {
    int weatherType;
    int currentTemperature;
    int highestTemperature;
    int lowestTemperature;
    NSString * strCity;
} MyWeatherParameter_X3;

typedef struct BreathParameter_X3 {
    int breathMode; //  0  1  2 three mode 
    int DurationOfBreathingExercise;
} MyBreathParameter_X3;

typedef struct SocialDistanceReminder_X3 {
    char scanInterval;
    char scanTime;
    char signalStrength;
} MySocialDistanceReminder_X3;


typedef NS_ENUM(NSInteger, MeasurementDataType_X3) {
    heartRateData_X3    = 2,
    spo2Data_X3 = 3
  
};

typedef NS_ENUM(NSInteger, ACTIVITYMODE_X3) {
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

typedef NS_ENUM(NSInteger, WORKMODE_X3) {
    startActivity = 1,
    pauseActivity    = 2,
    continueActivity = 3,
    stopActivity    = 4
};


#endif /* BleSDK_Header_X3_h */
