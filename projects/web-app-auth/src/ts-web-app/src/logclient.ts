/**
 * File: logclient.ts
 * 
 * Description: 
 *  This file contains the implementation of the LogClient class 
 *  
 */
 import { ApplicationInsights } from '@microsoft/applicationinsights-web'





export enum LogLevel {
  debug = 1,
  log,
  info,
  warn,
  error,
}

export class LogClient {
  logLevel: LogLevel = LogLevel.error;
  applicationInsights: ApplicationInsights | null = null;
  static getLogLevelFromString(s: string): LogLevel {
    let level: LogLevel = LogLevel.debug;
    if (s == "degug")
      level = LogLevel.debug;
    else if (s == "info")
      level = LogLevel.info;
    else if (s == "log")
      level = LogLevel.log;
    else if (s == "warn")
      level = LogLevel.warn;
    else if (s == "error")
      level = LogLevel.error;
    return level;
  }
  constructor(level: LogLevel, key: string | null = null) {
    this.logLevel = level;
    if(key !== null){
      this.applicationInsights = new ApplicationInsights({ config: {
        instrumentationKey: key
      } });
      this.applicationInsights.loadAppInsights();
      this.applicationInsights.trackPageView();      
    }
  }
  getLogLevel(): LogLevel {
    return this.logLevel;
  }
  setLogLevel(level: LogLevel): void {
    this.logLevel = level;
  }
  logEnable(): boolean {
    return (this.logLevel <= LogLevel.log)
  }
  infoEnable(): boolean {
    return (this.logLevel <= LogLevel.info)
  }
  debugEnable(): boolean {
    return (this.logLevel <= LogLevel.debug)
  }
  warnEnable(): boolean {
    return (this.logLevel <= LogLevel.warn)
  }
  errorEnable(): boolean {
    return (this.logLevel <= LogLevel.error)
  }
  log(message: any): void {
    if (this.logEnable()){
      console.log(message);
      this.trackTrace(message);
    }
  }
  info(message: any): void {
    if (this.infoEnable()){
      console.info(message);
      this.trackTrace(message);
    }

  }
  debug(message: any): void {
    if (this.debugEnable()){
      console.debug(message);
      this.trackTrace(message);
    }
  }
  warn(message: any): void {
    if (this.warnEnable()){
      console.warn(message);
      this.trackTrace(message);
    }
  }
  error(message: any): void {
    if (this.errorEnable()){
      console.error(message);
      this.trackTrace(message);
    }
  }
  trackFlush(): void {
    if (this.applicationInsights)
      this.applicationInsights.flush();
  }
  trackEvent(event: string): void {
    if (this.applicationInsights)
      this.applicationInsights.trackEvent({name: event});
  }
  trackTrace(message: string): void {
    if (this.applicationInsights)
      this.applicationInsights.trackEvent({name: message});
  }
  trackException(message: string): void {
    if (this.applicationInsights)
      this.applicationInsights.trackException({exception: new Error(message)});
  }
  trackMetric(metric: string, value: number): void {
    if (this.applicationInsights)
      this.applicationInsights.trackMetric({name: metric, average: value});
  }

  trackPageView(page: string): void {
    if (this.applicationInsights)
      this.applicationInsights.trackPageView({name: page});
  }
  trackPageViewPerformance(page: string, pageUrl: string): void {
    if (this.applicationInsights)
      this.applicationInsights.trackPageViewPerformance({name: page, uri: pageUrl});
  }
}