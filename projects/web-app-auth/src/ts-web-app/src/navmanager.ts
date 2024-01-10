/**
 * File: navmanager.ts
 * 
 * Description: 
 *  This file contains the implementation of the NavigationManager class 
 *  
 */

interface PageNavigateCallback {
  (manager: NavigationManager, pageId: string): void;
}
interface PageConditionCallback {
  (manager: NavigationManager, pageId: string): boolean;
}
interface SetPageContentCallback {
  (manager: NavigationManager, content: string): void;
}

export type PageConfiguration = {
  pageId: string;
  pageTitle: string;
  pageHTMLUri: string | null;
  pageJavascriptUri: string | null;
  pageNavigateFunction: PageNavigateCallback | null;
  pageConditionFunction: PageConditionCallback | null;
};

export class NavigationManager {
  navId: string;
  burgerId: string;
  childId: string;
  language: string;
  colorTheme: string;
  pageMap: Map<string, PageConfiguration>;

  // Variable where the latest page id is stored
  latestPageId = "";
  // Stores the cached partial HTML pages content.
  // Keys correspond to fragment identifiers.
  // Values are the text content of each loaded partial HTML file.
  partialsHTMLCache: { [page: string]: string } = {};

  constructor() {
    this.navId = "";
    this.burgerId = "";
    this.childId = "";
    this.language = "en";
    this.colorTheme = "blue";
    this.pageMap = new Map<string, PageConfiguration>([]);
    this.partialsHTMLCache = {};
  }

  initialization(
    navId: string,
    burgerId: string,
    childId: string,
    language: string,
    colorTheme: string,
    pageArray: Array<PageConfiguration>
  ): boolean {
    this.navId = navId;
    this.burgerId = burgerId;
    this.childId = childId;
    this.language = language;
    this.colorTheme = colorTheme;

    // Create Control
    // TODO

    // Initialize pageMap
    if (pageArray) {
      this.pageMap = new Map<string, PageConfiguration>();
      let i: number;
      for (i = 0; i < pageArray.length; i++) {
        this.pageMap.set(pageArray[i].pageId, pageArray[i])
      }
    }
    // Initialize Click events
    this.initializeClicks();

    // Clear Cache
    this.partialsHTMLCache = {};

    // Set Home page,
    if (pageArray && pageArray.length > 0) {
      if (!location.hash) {
        // default to #home.
        location.hash = `#${pageArray[0].pageId}`;
      }
    }

    // Navigate whenever the page identifier value changes.
    window.addEventListener("hashchange", async () => {
      await this.navigate();
    });

    // Set Color Theme
    document.documentElement.setAttribute('theme', colorTheme);

    return true;
  }



  initializeClicks() {
    const navbarDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.navId));
    if (navbarDiv) {
      const links: HTMLCollection = navbarDiv.getElementsByTagName("button");
      if (links) {
        let i: number;
        for (i = 0; i < links.length; i++) {
          const link: Element = links[i];
          if (link) {
            const linkName: string | null = link.getAttribute("href");
            if (linkName) {
              console.log(`HREF: ${linkName}`);
              const pageName: string = linkName.substring(1);
              if (this.pageMap.has(pageName)) {
                (link as HTMLElement).addEventListener("click", (e: Event) => {
                  const config = this.pageMap.get(pageName);
                  if ((config) && (config.pageNavigateFunction)) {
                    console.log(`Event click ${e} for page: ${pageName}`);
                    config.pageNavigateFunction(this, pageName);
                  }
                });
                console.log(`Click event set for: ${pageName}`);
              }
            }
          }
        }
      }
    }
  }



  // Encapsulates an HTTP GET request using XMLHttpRequest.
  // Fetches the file at the given path, then
  // calls the callback with the text content of the file.
  fetchFile(path: string, manager: NavigationManager, callback: SetPageContentCallback) {

    // Create a new AJAX request for fetching the partial HTML file.
    const request = new XMLHttpRequest();

    // Call the callback with the content loaded from the file.
    request.onload = function () {
      callback(manager, request.responseText);
    };

    // Fetch the partial HTML file for the given fragment id.
    request.open("GET", path);
    request.send(null);
  }

  async getFileContentAsync(url: string) {
    const p = new Promise<any>(resolve => this.getFileContent(url, resolve));
    const result = await p;
    return result;
  }

  getFileContent(url: string, resolve: any) {
    try {

      // Create a new AJAX request for fetching the partial HTML file.
      const request = new XMLHttpRequest();

      // Call the callback with the content loaded from the file.
      request.onload = () => {
        resolve(request.responseText);
      };

      // Fetch the partial HTML file for the given fragment id.
      request.open("GET", url);
      request.setRequestHeader("Content-Type", "text/html; charset=utf-8");
      request.setRequestHeader("Cache-Control", "3600");
      request.send(null);
    }
    catch (e) {
      resolve(null);
      if (e instanceof Error)
        console.log(`Error while opening ${url}:  ${e.message}`);
      else
        console.log(`Error while opening ${url}:  ${String(e)}`);
    }
  }
  // Gets the appropriate content for the given fragment identifier.
  // This function implements a simple cache.
  async getPageContentAsync(pageId: string) {
    let content: string | null = null;
    // If the page has been fetched before,
    if (this.partialsHTMLCache[pageId]) {
      // pass the previously fetched content to the callback.
      content = this.partialsHTMLCache[pageId];
    } else {
      const config = this.pageMap.get(pageId);
      if ((config) && (config.pageHTMLUri)) {
        content = await this.getFileContentAsync(config.pageHTMLUri);
        if (content) {
          // Store the fetched content in the cache.
          if (globalThis.globalVars.getGlobalCache() == true)
            this.partialsHTMLCache[pageId] = content;
        }
      }
    }
    // Get a reference to the "content" div.
    const contentDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.childId));
    if (contentDiv) {
      if (content) {
        this.removeAllScripts();
        contentDiv.innerHTML = content;
        this.addScript(pageId);
      }
      else {
        this.removeAllScripts();
        contentDiv.innerHTML = "";
      }
    }
  }

  async selectPage(pageId: string) {
    const href = `#${pageId}`;
    location.hash = href;
    //var link:string = href.substring(1);
    //setActiveLink(link);
    await this.navigate();
  }




  setActiveLink(pageId: string): void {
    //console.log(`setActiveLink: ${pageId}`);
    const navbarDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById("navbarsExampleDefault"));
    if (navbarDiv) {
      const links: HTMLCollection = navbarDiv.getElementsByTagName("button");
      if (links) {
        //console.log(`navbarDiv len: ${links.length}`);
        let i: number;
        for (i = 0; i < links.length; i++) {
          const link: Element = links[i];
          if (link) {
            const linkName: string | null = link.getAttribute("href");
            if (linkName) {
              const pageName: string = linkName.substring(1);
              if (pageName === pageId) {
                (link as HTMLElement).classList.add('active');
                (link as HTMLElement).style.backgroundColor = getComputedStyle(document.documentElement)
                  .getPropertyValue('--mini-button-bg-active-color'); // #999999              
                // check for focus
                const isFocused = (document.activeElement === link);
                if (isFocused != true) {
                  (link as HTMLElement).focus();
                }
              } else {
                (link as HTMLElement).classList.remove('active');
                (link as HTMLElement).style.backgroundColor = 'Transparent';
              }
              if (this.pageMap.has(pageName)) {
                const config = this.pageMap.get(pageName);
                if ((config) && (config.pageConditionFunction)) {
                  if (config.pageConditionFunction(this, pageName))
                    (link as HTMLElement).classList.remove('d-none');
                  else
                    (link as HTMLElement).classList.add('d-none');
                }
              }
            }
          }
        }
      }
    }
  }
  isChildPage(pagePath: string): boolean {
    for (const value of Array.from(this.pageMap.values())) {
      if (value.pageHTMLUri)
        if (pagePath.endsWith(value.pageHTMLUri))
          return true;
    }
    return false;
  }

  removeAllScripts() {
    const scripts = document.body.getElementsByTagName("script");
    // console.log(scripts.length);
    for (let i = scripts.length - 1; i >= 0; i--) {
      if (scripts[i].src) {
        //console.log(i, scripts[i].src);
        if (this.isChildPage(scripts[i].src)) {
          //console.log(i, scripts[i].src);
          scripts[i].parentElement?.removeChild(scripts[i]);
        }
      }
    }
  }

  addScript(pageId: string) {
    if (this.pageMap.has(pageId)) {
      const script = document.createElement('script');
      const config = this.pageMap.get(pageId);
      if ((config) && (config.pageJavascriptUri))
        script.setAttribute('src', config.pageJavascriptUri);
      script.setAttribute('type', 'text/javascript');
      document.body.appendChild(script);
    }
  }

  isPageAllowed(pageName: string): boolean {
    if (this.pageMap.has(pageName)) {
      const config = this.pageMap.get(pageName);
      if ((config) && (config.pageConditionFunction)) {
        if (config.pageConditionFunction(this, pageName))
          return true;
      }
    }
    return false;
  }
  getFirstPageAllowed(): string | null {
    for (const value of Array.from(this.pageMap.values())) {
      if ((value) && (value.pageConditionFunction)) {
        if (value.pageConditionFunction(this, value.pageId))
          return value.pageId;
      }
    }
    return null;
  }

  // Updates dynamic content based on the fragment identifier.
  async navigate() {
    // Isolate the fragment identifier using substr.
    // This gets rid of the "#" character.
    let pageId: string = location.hash.substring(1);

    if (!this.isPageAllowed(pageId)) {
      const newPage = this.getFirstPageAllowed();
      if (newPage) {
        location.hash = `#${newPage}`;
        pageId = newPage;
      }
      else {
        console.log("No page found");
        return
      }
    }

    if (this.latestPageId != pageId) {
      this.latestPageId = pageId;

      // Set the "content" div innerHTML based on the fragment identifier.
      await this.getPageContentAsync(pageId);

      // Toggle the "active" class on the link currently navigated to.
      this.setActiveLink(pageId);

      // Hide burger Menu
      this.HideBurgerMenu()
    }
  }

  HideBurgerMenu(): void {
    const button: HTMLButtonElement = (<HTMLButtonElement>document.getElementById(this.burgerId));
    if (button) {
      button.classList.add("collapsed");
    }
    const nav = (<HTMLDivElement>document.getElementById(this.navId));
    if (nav) {
      nav.classList.remove("show");
    }
  }
}
